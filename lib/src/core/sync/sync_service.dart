import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/database_service.dart';
import '../network/dio_client.dart';
import '../config/api_config.dart';
import '../services/connectivity_service.dart';
import '../services/logger_service.dart';
import 'sync_queue_service.dart';

enum SyncState { idle, syncing, error, offline }

class SyncService {
  SyncService._();
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;

  final _stateController = StreamController<SyncState>.broadcast();
  StreamSubscription<ConnectionStatus>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncState _currentState = SyncState.idle;
  bool _isSyncing = false;

  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState get currentState => _currentState;

  AppDatabase get _db => DatabaseService().database;
  DioClient get _dio => DioClient();
  SyncQueueService get _queue => SyncQueueService();

  void initialize() {
    _connectivitySubscription = ConnectivityService().statusStream.listen((status) {
      if (status == ConnectionStatus.online) {
        _setState(SyncState.idle);
        performSync();
      } else {
        _setState(SyncState.offline);
      }
    });

    if (!ConnectivityService().isOnline) {
      _setState(SyncState.offline);
    }

    // Periodic sync every 5 minutes
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (ConnectivityService().isOnline) {
        performSync();
      }
    });
  }

  void _setState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
  }

  Future<void> performSync() async {
    if (_isSyncing || !ConnectivityService().isOnline) return;

    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      // Phase 1: Push local changes
      await _pushChanges();

      // Phase 2: Pull server changes
      await _pullChanges();

      _setState(SyncState.idle);
    } catch (e) {
      AppLogger.error('Sync failed: $e');
      _setState(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> performInitialSync() async {
    if (!ConnectivityService().isOnline) {
      AppLogger.info('Offline - skipping initial sync');
      return;
    }

    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      await _pullChanges(); // since=null means full sync
      _setState(SyncState.idle);
    } catch (e) {
      AppLogger.error('Initial sync failed: $e');
      _setState(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushChanges() async {
    final pendingOps = await _queue.getPendingOperations();
    if (pendingOps.isEmpty) return;

    AppLogger.info('Pushing ${pendingOps.length} changes to server');

    final changes = pendingOps.map((op) {
      return {
        'entity_type': op.entityType,
        'entity_id': op.entityId,
        'operation': op.operation,
        'data': jsonDecode(op.payload),
        if (op.operation == 'update') 'base_version': jsonDecode(op.payload)['_base_version'],
      };
    }).toList();

    try {
      final response = await _dio.post(
        '${ApiConfig.sync}/push',
        data: {'changes': changes},
      );

      final results = (response.data['results'] as List?) ?? [];
      for (var i = 0; i < results.length && i < pendingOps.length; i++) {
        final result = results[i] as Map<String, dynamic>;
        final op = pendingOps[i];
        final status = result['status'] as String;

        if (status == 'ok') {
          await _queue.markCompleted(op.id);
          // Update local entity with server data if returned
          if (result['data'] != null) {
            await _updateLocalFromServerData(
              op.entityType,
              op.entityId,
              result['data'] as Map<String, dynamic>,
            );
          }
          // Clear dirty flag
          await _clearDirtyFlag(op.entityType, op.entityId);
        } else if (status == 'conflict') {
          // Accept server version for now (last-writer-wins)
          await _queue.markCompleted(op.id);
          if (result['server_version'] != null) {
            await _updateLocalFromServerData(
              op.entityType,
              op.entityId,
              result['server_version'] as Map<String, dynamic>,
            );
          }
          await _clearDirtyFlag(op.entityType, op.entityId);
        } else {
          // Error - increment retry
          final error = result['error'] as String? ?? 'Unknown error';
          await _queue.markFailed(op.id, error);
        }
      }
    } catch (e) {
      AppLogger.error('Push failed: $e');
      // Don't rethrow - we'll try again later
    }
  }

  Future<void> _pullChanges() async {
    final lastSyncAt = await _db.syncQueueDao.getLastSyncAt();
    AppLogger.info('Pulling changes since: ${lastSyncAt ?? "beginning"}');

    try {
      final response = await _dio.post(
        '${ApiConfig.sync}/pull',
        data: {'since': lastSyncAt},
      );

      final data = response.data as Map<String, dynamic>;
      final serverTime = data['server_time'] as String;
      final changes = data['changes'] as Map<String, dynamic>;

      await _db.transaction(() async {
        await _processEntityChanges('trips', changes['trips'], _upsertTrip, _deleteTrip);
        await _processEntityChanges('activities', changes['activities'], _upsertActivity, _deleteEntity);
        await _processEntityChanges('expenses', changes['expenses'], _upsertExpense, _deleteEntity);
        await _processEntityChanges('memories', changes['memories'], _upsertMemory, _deleteEntity);
        await _processEntityChanges('documents', changes['documents'], _upsertDocument, _deleteEntity);
        await _processEntityChanges('packing_items', changes['packing_items'], _upsertPackingItem, _deleteEntity);
        await _processEntityChanges('trip_shares', changes['trip_shares'], _upsertTripShare, _deleteEntity);
      });

      await _db.syncQueueDao.setLastSyncAt(serverTime);
      AppLogger.info('Pull completed, server time: $serverTime');
    } catch (e) {
      AppLogger.error('Pull failed: $e');
      rethrow;
    }
  }

  Future<void> _processEntityChanges(
    String entityType,
    Map<String, dynamic>? changes,
    Future<void> Function(Map<String, dynamic>) upsertFn,
    Future<void> Function(String entityType, String id) deleteFn,
  ) async {
    if (changes == null) return;

    final upserted = (changes['upserted'] as List?) ?? [];
    final deleted = (changes['deleted'] as List?) ?? [];

    for (final item in upserted) {
      await upsertFn(item as Map<String, dynamic>);
    }

    for (final item in deleted) {
      final id = (item as Map<String, dynamic>)['id'] as String;
      await deleteFn(entityType, id);
    }
  }

  // ─── Upsert Handlers ─────────────────────────────────────────

  Future<void> _upsertTrip(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.tripsDao.getById(id);
    if (existing != null && existing.isDirty) return; // Don't overwrite local changes

    await _db.tripsDao.upsert(LocalTripsCompanion(
      id: Value(id),
      userId: Value(data['user_id'] as String),
      title: Value(data['title'] as String),
      description: Value(data['description'] as String?),
      coverImageUrl: Value(data['cover_image_url'] as String?),
      startDate: Value(data['start_date'] as String),
      endDate: Value(data['end_date'] as String?),
      status: Value(data['status'] as String),
      tags: Value(jsonEncode(data['tags'] ?? [])),
      budget: Value((data['budget'] as num?)?.toDouble()),
      displayCurrency: Value(data['display_currency'] as String? ?? 'USD'),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertActivity(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.activitiesDao.getById(id);
    if (existing != null && existing.isDirty) return;

    await _db.activitiesDao.upsert(LocalActivitiesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      title: Value(data['title'] as String),
      description: Value(data['description'] as String?),
      scheduledTime: Value(data['scheduled_time'] as String),
      category: Value(data['category'] as String),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      latitude: Value((data['latitude'] as num?)?.toDouble()),
      longitude: Value((data['longitude'] as num?)?.toDouble()),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertExpense(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.expensesDao.getById(id);
    if (existing != null && existing.isDirty) return;

    await _db.expensesDao.upsert(LocalExpensesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      title: Value(data['title'] as String),
      amount: Value((data['amount'] as num).toDouble()),
      currency: Value(data['currency'] as String? ?? 'USD'),
      category: Value(data['category'] as String),
      date: Value(data['date'] as String),
      notes: Value(data['notes'] as String?),
      convertedAmount: Value((data['converted_amount'] as num?)?.toDouble()),
      convertedCurrency: Value(data['converted_currency'] as String?),
      exchangeRate: Value((data['exchange_rate'] as num?)?.toDouble()),
      convertedAt: Value(data['converted_at'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertMemory(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.memoriesDao.getById(id);
    if (existing != null && existing.isDirty) return;

    await _db.memoriesDao.upsert(LocalMemoriesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      mediaItems: Value(jsonEncode(data['media_items'] ?? [])),
      photoUrl: Value(data['photo_url'] as String?),
      location: Value(data['location'] as String?),
      latitude: Value((data['latitude'] as num?)?.toDouble()),
      longitude: Value((data['longitude'] as num?)?.toDouble()),
      caption: Value(data['caption'] as String?),
      takenAt: Value(data['taken_at'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.now()),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertDocument(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.documentsDao.getById(id);
    if (existing != null && existing.isDirty) return;

    await _db.documentsDao.upsert(LocalDocumentsCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      type: Value(data['type'] as String),
      name: Value(data['name'] as String),
      files: Value(jsonEncode(data['files'] ?? [])),
      fileUrl: Value(data['file_url'] as String?),
      fileType: Value(data['file_type'] as String?),
      notes: Value(data['notes'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertPackingItem(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final existing = await _db.packingDao.getById(id);
    if (existing != null && existing.isDirty) return;

    await _db.packingDao.upsert(LocalPackingItemsCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      name: Value(data['name'] as String),
      category: Value(data['category'] as String),
      isPacked: Value(data['is_packed'] as bool? ?? false),
      quantity: Value(data['quantity'] as int? ?? 1),
      notes: Value(data['notes'] as String?),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertTripShare(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final companion = LocalTripSharesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      ownerId: Value(data['owner_id'] as String),
      sharedWithEmail: Value(data['shared_with_email'] as String),
      sharedWithUserId: Value(data['shared_with_user_id'] as String?),
      permission: Value(data['permission'] as String),
      inviteCode: Value(data['invite_code'] as String),
      status: Value(data['status'] as String),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      acceptedAt: Value(data['accepted_at'] as String?),
    );
    await _db.into(_db.localTripShares).insertOnConflictUpdate(companion);
  }

  // ─── Delete Handlers ──────────────────────────────────────────

  Future<void> _deleteTrip(String entityType, String id) async {
    await _db.tripsDao.hardDelete(id);
  }

  Future<void> _deleteEntity(String entityType, String id) async {
    switch (entityType) {
      case 'activities':
        await _db.activitiesDao.hardDelete(id);
      case 'expenses':
        await _db.expensesDao.hardDelete(id);
      case 'memories':
        await _db.memoriesDao.hardDelete(id);
      case 'documents':
        await _db.documentsDao.hardDelete(id);
      case 'packing_items':
        await _db.packingDao.hardDelete(id);
      case 'trip_shares':
        await (_db.delete(_db.localTripShares)..where((s) => s.id.equals(id))).go();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Future<void> _updateLocalFromServerData(
    String entityType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    switch (entityType) {
      case 'trip':
        await _upsertTrip({...data, 'id': entityId});
      case 'activity':
        await _upsertActivity({...data, 'id': entityId});
      case 'expense':
        await _upsertExpense({...data, 'id': entityId});
      case 'memory':
        await _upsertMemory({...data, 'id': entityId});
      case 'document':
        await _upsertDocument({...data, 'id': entityId});
      case 'packing_item':
        await _upsertPackingItem({...data, 'id': entityId});
    }
  }

  Future<void> _clearDirtyFlag(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        await _db.tripsDao.clearDirty(entityId);
      case 'activity':
        await _db.activitiesDao.clearDirty(entityId);
      case 'expense':
        await _db.expensesDao.clearDirty(entityId);
      case 'memory':
        await _db.memoriesDao.clearDirty(entityId);
      case 'document':
        await _db.documentsDao.clearDirty(entityId);
      case 'packing_item':
        await _db.packingDao.clearDirty(entityId);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _stateController.close();
  }
}
