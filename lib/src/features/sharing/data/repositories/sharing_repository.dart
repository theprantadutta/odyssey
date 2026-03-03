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
import '../models/trip_share_model.dart';

/// Sharing repository - local-first with cache and queued mutations
class SharingRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Share a trip with another user
  Future<TripShareModel> shareTrip(
    String tripId,
    TripShareRequest request,
  ) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final share = TripShareModel(
      id: id,
      tripId: tripId,
      ownerId: '',
      sharedWithEmail: request.email,
      permission: request.permission,
      inviteCode: '',
      status: ShareStatus.pending,
      createdAt: now,
    );

    await _db.sharesDao.upsert(tripShareToLocal(share, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'trip_share',
      entityId: id,
      operation: 'create',
      payload: {'trip_id': tripId, ...request.toJson()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post(
          ApiConfig.shareTrip(tripId),
          data: request.toJson(),
        );
        final serverShare = TripShareModel.fromJson(response.data as Map<String, dynamic>);
        await _db.sharesDao.upsert(tripShareToLocal(serverShare));
        // Remove the placeholder if server assigned a different ID
        if (serverShare.id != id) {
          await _db.sharesDao.hardDelete(id);
        }
        await _db.syncQueueDao.removeForEntity('trip_share', id);
        return serverShare;
      } catch (e) {
        AppLogger.warning('Failed to sync share create, will retry: $e');
      }
    }

    return share;
  }

  /// Get all shares for a trip - reads from local DB, triggers background refresh
  Future<TripSharesResponse> getTripShares(String tripId) async {
    final localShares = await _db.sharesDao.getByTrip(tripId);

    if (localShares.isNotEmpty || !ConnectivityService().isOnline) {
      final shares = localShares.map(tripShareFromLocal).toList();

      if (ConnectivityService().isOnline) {
        _refreshTripSharesFromApi(tripId);
      }

      return TripSharesResponse(shares: shares, total: shares.length);
    }

    return _fetchTripSharesFromApi(tripId);
  }

  /// Update share permission
  Future<TripShareModel> updateSharePermission(
    String tripId,
    String shareId,
    SharePermission permission,
  ) async {
    final existing = await _db.sharesDao.getById(shareId);
    if (existing != null) {
      await (_db.update(_db.localTripShares)..where((s) => s.id.equals(shareId))).write(
        LocalTripSharesCompanion(
          permission: Value(permission.name),
          isDirty: const Value(true),
        ),
      );
    }

    await SyncQueueService().enqueue(
      entityType: 'trip_share',
      entityId: shareId,
      operation: 'update',
      payload: {'trip_id': tripId, 'permission': permission.name},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch(
          '${ApiConfig.tripShares(tripId)}/$shareId',
          data: {'permission': permission.name},
        );
        final serverShare = TripShareModel.fromJson(response.data as Map<String, dynamic>);
        await _db.sharesDao.upsert(tripShareToLocal(serverShare));
        await _db.syncQueueDao.removeForEntity('trip_share', shareId);
        return serverShare;
      } catch (e) {
        AppLogger.warning('Failed to sync share update, will retry: $e');
      }
    }

    final updated = await _db.sharesDao.getById(shareId);
    return updated != null ? tripShareFromLocal(updated) : throw 'Share not found';
  }

  /// Revoke a share
  Future<void> revokeShare(String tripId, String shareId) async {
    await _db.sharesDao.softDelete(shareId);

    await SyncQueueService().enqueue(
      entityType: 'trip_share',
      entityId: shareId,
      operation: 'delete',
      payload: {'trip_id': tripId},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.tripShares(tripId)}/$shareId');
        await _db.sharesDao.hardDelete(shareId);
        await _db.syncQueueDao.removeForEntity('trip_share', shareId);
      } catch (e) {
        AppLogger.warning('Failed to sync share revoke, will retry: $e');
      }
    }
  }

  /// Get invite details by code - API-only
  Future<InviteDetailsModel> getInviteDetails(String inviteCode) async {
    if (!ConnectivityService().isOnline) {
      throw 'Viewing invite details requires an internet connection';
    }
    try {
      final response = await _dioClient.get(ApiConfig.inviteDetails(inviteCode));
      return InviteDetailsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Accept an invite - API-only
  Future<AcceptInviteResponse> acceptInvite(String inviteCode) async {
    if (!ConnectivityService().isOnline) {
      throw 'Accepting invites requires an internet connection';
    }
    try {
      final response = await _dioClient.post(ApiConfig.acceptInvite(inviteCode));
      return AcceptInviteResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Decline an invite - API-only
  Future<void> declineInvite(String inviteCode) async {
    if (!ConnectivityService().isOnline) {
      throw 'Declining invites requires an internet connection';
    }
    try {
      await _dioClient.post(ApiConfig.declineInvite(inviteCode));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get trips shared with the current user - reads from local cache
  Future<SharedTripsResponse> getSharedTrips() async {
    final localShared = await _db.sharesDao.getAllShared();

    if (localShared.isNotEmpty || !ConnectivityService().isOnline) {
      final trips = localShared.map(sharedTripFromLocal).toList();

      if (ConnectivityService().isOnline) {
        _refreshSharedTripsFromApi();
      }

      return SharedTripsResponse(trips: trips, total: trips.length);
    }

    return _fetchSharedTripsFromApi();
  }

  // --- Private Methods ---

  Future<TripSharesResponse> _fetchTripSharesFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(ApiConfig.tripShares(tripId));
      final sharesResponse = TripSharesResponse.fromJson(response.data as Map<String, dynamic>);

      for (final share in sharesResponse.shares) {
        await _db.sharesDao.upsert(tripShareToLocal(share));
      }

      return sharesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshTripSharesFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(ApiConfig.tripShares(tripId));
      final sharesResponse = TripSharesResponse.fromJson(response.data as Map<String, dynamic>);
      for (final share in sharesResponse.shares) {
        final existing = await _db.sharesDao.getById(share.id);
        if (existing == null || !existing.isDirty) {
          await _db.sharesDao.upsert(tripShareToLocal(share));
        }
      }
    } catch (e) {
      AppLogger.warning('Background trip shares refresh failed: $e');
    }
  }

  Future<SharedTripsResponse> _fetchSharedTripsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.sharedWithMe);
      final sharedResponse = SharedTripsResponse.fromJson(response.data as Map<String, dynamic>);

      for (final trip in sharedResponse.trips) {
        await _db.sharesDao.upsertShared(sharedTripToLocal(trip));
      }

      return sharedResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshSharedTripsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.sharedWithMe);
      final sharedResponse = SharedTripsResponse.fromJson(response.data as Map<String, dynamic>);
      for (final trip in sharedResponse.trips) {
        await _db.sharesDao.upsertShared(sharedTripToLocal(trip));
      }
    } catch (e) {
      AppLogger.warning('Background shared trips refresh failed: $e');
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
