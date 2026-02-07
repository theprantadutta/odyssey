import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../models/packing_model.dart';

/// Packing repository - local-first with background API sync
class PackingRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all packing items for a trip - reads from local DB, triggers background API refresh
  Future<PackingListResponse> getPackingItems({
    required String tripId,
    String? category,
  }) async {
    final localItems = await _db.packingDao.getByTrip(tripId);

    if (localItems.isNotEmpty || !ConnectivityService().isOnline) {
      var items = localItems.map(packingItemFromLocal).toList();

      if (category != null) {
        items = items.where((i) => i.category == category).toList();
      }

      final packedCount = items.where((i) => i.isPacked).length;

      if (ConnectivityService().isOnline) {
        _refreshFromApi(tripId);
      }

      return PackingListResponse(
        items: items,
        total: items.length,
        packedCount: packedCount,
        unpackedCount: items.length - packedCount,
      );
    }

    // No local data - fetch from API
    return _fetchFromApi(tripId: tripId, category: category);
  }

  /// Get packing progress - computes locally or fetches from API
  Future<PackingProgressResponse> getPackingProgress({
    required String tripId,
  }) async {
    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.get(
          '${ApiConfig.packing}/progress',
          queryParameters: {'trip_id': tripId},
        );
        return PackingProgressResponse.fromJson(response.data);
      } on DioException catch (e) {
        // Fall through to local computation
        AppLogger.warning('Failed to get packing progress from API: $e');
      }
    }

    // Compute locally
    final localItems = await _db.packingDao.getByTrip(tripId);
    final items = localItems.map(packingItemFromLocal).toList();
    final totalItems = items.length;
    final packedItems = items.where((i) => i.isPacked).length;
    final progressPercent = totalItems > 0 ? (packedItems / totalItems) * 100 : 0.0;

    // Group by category
    final categoryMap = <String, List<PackingItemModel>>{};
    for (final item in items) {
      categoryMap.putIfAbsent(item.category, () => []).add(item);
    }

    final byCategory = categoryMap.entries.map((entry) {
      final catPacked = entry.value.where((i) => i.isPacked).length;
      return CategoryProgress(
        category: entry.key,
        total: entry.value.length,
        packed: catPacked,
        progressPercent: entry.value.isNotEmpty ? (catPacked / entry.value.length) * 100 : 0.0,
      );
    }).toList();

    return PackingProgressResponse(
      totalItems: totalItems,
      packedItems: packedItems,
      progressPercent: progressPercent,
      byCategory: byCategory,
    );
  }

  /// Get packing item by ID - reads from local DB first
  Future<PackingItemModel> getPackingItemById(String id) async {
    final local = await _db.packingDao.getById(id);
    if (local != null && !local.isDeleted) {
      return packingItemFromLocal(local);
    }

    try {
      final response = await _dioClient.get('${ApiConfig.packing}/$id');
      final item = PackingItemModel.fromJson(response.data);
      await _db.packingDao.upsert(packingItemToLocal(item));
      return item;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new packing item - writes to local DB immediately, syncs in background
  Future<PackingItemModel> createPackingItem(PackingItemRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final item = PackingItemModel(
      id: id,
      tripId: request.tripId,
      name: request.name,
      category: request.category,
      isPacked: request.isPacked,
      quantity: request.quantity,
      notes: request.notes,
      sortOrder: 0,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    await _db.packingDao.upsert(packingItemToLocal(item, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'packing_item',
      entityId: id,
      operation: 'create',
      payload: request.toJson(),
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post('${ApiConfig.packing}/', data: request.toJson());
        final serverItem = PackingItemModel.fromJson(response.data);
        await _db.packingDao.upsert(packingItemToLocal(serverItem));
        await _db.syncQueueDao.removeForEntity('packing_item', id);
        return serverItem;
      } catch (e) {
        AppLogger.warning('Failed to sync packing item create, will retry: $e');
      }
    }

    return item;
  }

  /// Update packing item - writes to local DB immediately, syncs in background
  Future<PackingItemModel> updatePackingItem(String id, Map<String, dynamic> updates) async {
    final existing = await _db.packingDao.getById(id);
    if (existing != null) {
      final updatedCompanion = LocalPackingItemsCompanion(
        id: Value(id),
        name: updates.containsKey('name') ? Value(updates['name'] as String) : const Value.absent(),
        category: updates.containsKey('category') ? Value(updates['category'] as String) : const Value.absent(),
        isPacked: updates.containsKey('is_packed') ? Value(updates['is_packed'] as bool) : const Value.absent(),
        quantity: updates.containsKey('quantity') ? Value(updates['quantity'] as int) : const Value.absent(),
        notes: updates.containsKey('notes') ? Value(updates['notes'] as String?) : const Value.absent(),
        sortOrder: updates.containsKey('sort_order') ? Value(updates['sort_order'] as int) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localPackingItems))..where((t) => t.id.equals(id))).write(updatedCompanion);
    }

    await SyncQueueService().enqueue(
      entityType: 'packing_item',
      entityId: id,
      operation: 'update',
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch('${ApiConfig.packing}/$id', data: updates);
        final serverItem = PackingItemModel.fromJson(response.data);
        await _db.packingDao.upsert(packingItemToLocal(serverItem));
        await _db.syncQueueDao.removeForEntity('packing_item', id);
        return serverItem;
      } catch (e) {
        AppLogger.warning('Failed to sync packing item update, will retry: $e');
      }
    }

    final updated = await _db.packingDao.getById(id);
    return updated != null ? packingItemFromLocal(updated) : throw 'Packing item not found';
  }

  /// Toggle packed status - local-first with sync
  Future<PackingItemModel> togglePackedStatus(String id) async {
    final existing = await _db.packingDao.getById(id);
    if (existing != null) {
      final newPacked = !existing.isPacked;
      await ((_db.update(_db.localPackingItems))..where((t) => t.id.equals(id))).write(
        LocalPackingItemsCompanion(
          isPacked: Value(newPacked),
          updatedAt: Value(DateTime.now().toUtc()),
          isDirty: const Value(true),
        ),
      );

      await SyncQueueService().enqueue(
        entityType: 'packing_item',
        entityId: id,
        operation: 'update',
        payload: {'is_packed': newPacked, '_base_version': existing.updatedAt.toIso8601String()},
      );

      if (ConnectivityService().isOnline) {
        try {
          final response = await _dioClient.post('${ApiConfig.packing}/$id/toggle');
          final serverItem = PackingItemModel.fromJson(response.data);
          await _db.packingDao.upsert(packingItemToLocal(serverItem));
          await _db.syncQueueDao.removeForEntity('packing_item', id);
          return serverItem;
        } catch (e) {
          AppLogger.warning('Failed to sync packing toggle, will retry: $e');
        }
      }

      final updated = await _db.packingDao.getById(id);
      return updated != null ? packingItemFromLocal(updated) : throw 'Packing item not found';
    }

    // Fallback to API
    try {
      final response = await _dioClient.post('${ApiConfig.packing}/$id/toggle');
      return PackingItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Bulk toggle packed status - local-first with sync
  Future<void> bulkTogglePacked({
    required String tripId,
    required List<String> itemIds,
    required bool isPacked,
  }) async {
    // Update locally first
    for (final itemId in itemIds) {
      await ((_db.update(_db.localPackingItems))..where((t) => t.id.equals(itemId))).write(
        LocalPackingItemsCompanion(
          isPacked: Value(isPacked),
          updatedAt: Value(DateTime.now().toUtc()),
          isDirty: const Value(true),
        ),
      );
    }

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.post(
          '${ApiConfig.packing}/bulk-toggle',
          queryParameters: {'trip_id': tripId},
          data: {
            'item_ids': itemIds,
            'is_packed': isPacked,
          },
        );
        // Clear dirty flags
        for (final itemId in itemIds) {
          await _db.packingDao.clearDirty(itemId);
        }
      } catch (e) {
        AppLogger.warning('Failed to sync bulk toggle, will retry: $e');
      }
    }
  }

  /// Delete packing item - soft deletes locally, syncs in background
  Future<void> deletePackingItem(String id) async {
    await _db.packingDao.softDelete(id);

    await SyncQueueService().enqueue(
      entityType: 'packing_item',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.packing}/$id');
        await _db.packingDao.hardDelete(id);
        await _db.syncQueueDao.removeForEntity('packing_item', id);
      } catch (e) {
        AppLogger.warning('Failed to sync packing item delete, will retry: $e');
      }
    }
  }

  /// Reorder packing items - local update with sync
  Future<void> reorderPackingItems({
    required String tripId,
    required List<ItemOrderData> itemOrders,
  }) async {
    for (final order in itemOrders) {
      await ((_db.update(_db.localPackingItems))..where((t) => t.id.equals(order.id))).write(
        LocalPackingItemsCompanion(
          sortOrder: Value(order.sortOrder),
          updatedAt: Value(DateTime.now().toUtc()),
          isDirty: const Value(true),
        ),
      );
    }

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.put(
          '${ApiConfig.packing}/reorder',
          queryParameters: {'trip_id': tripId},
          data: {
            'item_orders': itemOrders.map((e) => e.toJson()).toList(),
          },
        );
        for (final order in itemOrders) {
          await _db.packingDao.clearDirty(order.id);
        }
      } catch (e) {
        AppLogger.warning('Failed to sync packing reorder, will retry: $e');
      }
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<PackingListResponse> _fetchFromApi({
    required String tripId,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (category != null) queryParams['category'] = category;

      final response = await _dioClient.get(ApiConfig.packing, queryParameters: queryParams);
      final packingResponse = PackingListResponse.fromJson(response.data);

      for (final item in packingResponse.items) {
        await _db.packingDao.upsert(packingItemToLocal(item));
      }

      return packingResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.packing,
        queryParameters: {'trip_id': tripId},
      );
      final packingResponse = PackingListResponse.fromJson(response.data);
      for (final item in packingResponse.items) {
        final existing = await _db.packingDao.getById(item.id);
        if (existing == null || !existing.isDirty) {
          await _db.packingDao.upsert(packingItemToLocal(item));
        }
      }
    } catch (e) {
      AppLogger.warning('Background packing refresh failed: $e');
    }
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
