import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/trip_model.dart';
import '../models/trip_filter_model.dart';

/// Trip repository for API calls
class TripRepository {
  final DioClient _dioClient = DioClient();

  /// Get all trips (paginated, with optional filtering)
  Future<TripsResponse> getTrips({
    int page = 1,
    int pageSize = 20,
    TripFilterModel? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      // Add filter params if provided
      if (filters != null) {
        queryParams.addAll(filters.toQueryParams());
      }

      final response = await _dioClient.get(
        ApiConfig.trips,
        queryParameters: queryParams,
      );

      return TripsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get trip by ID
  Future<TripModel> getTripById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.trips}/$id');
      return TripModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create new trip
  Future<TripModel> createTrip(TripRequest request) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.trips}/',
        data: request.toJson(),
      );

      return TripModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update trip
  Future<TripModel> updateTrip(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConfig.trips}/$id',
        data: updates,
      );

      return TripModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete trip
  Future<void> deleteTrip(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.trips}/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get available tags for user's trips
  Future<List<String>> getAvailableTags() async {
    try {
      final response = await _dioClient.get('${ApiConfig.trips}/tags');
      return List<String>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create default trips for new user (called during onboarding)
  Future<void> createDefaultTrips() async {
    try {
      await _dioClient.post(ApiConfig.defaultTrips);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
