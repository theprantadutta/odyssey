import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';

class SharingRepository {
  final DioClient _dioClient = DioClient();

  /// Share a trip with another user
  Future<TripShareModel> shareTrip(
    String tripId,
    TripShareRequest request,
  ) async {
    final response = await _dioClient.post(
      '/trips/$tripId/share',
      data: request.toJson(),
    );
    return TripShareModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get all shares for a trip
  Future<TripSharesResponse> getTripShares(String tripId) async {
    final response = await _dioClient.get('/trips/$tripId/shares');
    return TripSharesResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update share permission
  Future<TripShareModel> updateSharePermission(
    String tripId,
    String shareId,
    SharePermission permission,
  ) async {
    final response = await _dioClient.patch(
      '/trips/$tripId/shares/$shareId',
      data: {'permission': permission.name},
    );
    return TripShareModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Revoke a share
  Future<void> revokeShare(String tripId, String shareId) async {
    await _dioClient.delete('/trips/$tripId/shares/$shareId');
  }

  /// Get invite details by code
  Future<InviteDetailsModel> getInviteDetails(String inviteCode) async {
    final response = await _dioClient.get('/share/invite/$inviteCode');
    return InviteDetailsModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Accept an invite
  Future<AcceptInviteResponse> acceptInvite(String inviteCode) async {
    final response = await _dioClient.post('/share/accept/$inviteCode');
    return AcceptInviteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Decline an invite
  Future<void> declineInvite(String inviteCode) async {
    await _dioClient.post('/share/decline/$inviteCode');
  }

  /// Get trips shared with the current user
  Future<SharedTripsResponse> getSharedTrips() async {
    final response = await _dioClient.get('/trips/shared-with-me');
    return SharedTripsResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
