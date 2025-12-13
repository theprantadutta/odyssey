import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/packing_model.dart';

/// Packing repository for API calls
class PackingRepository {
  final DioClient _dioClient = DioClient();

  /// Get all packing items for a trip
  Future<PackingListResponse> getPackingItems({
    required String tripId,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _dioClient.get(
        ApiConfig.packing,
        queryParameters: queryParams,
      );

      return PackingListResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get packing progress
  Future<PackingProgressResponse> getPackingProgress({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConfig.packing}/progress',
        queryParameters: {'trip_id': tripId},
      );

      return PackingProgressResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get packing item by ID
  Future<PackingItemModel> getPackingItemById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.packing}/$id');
      return PackingItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new packing item
  Future<PackingItemModel> createPackingItem(PackingItemRequest request) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.packing}/',
        data: request.toJson(),
      );

      return PackingItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update packing item
  Future<PackingItemModel> updatePackingItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConfig.packing}/$id',
        data: updates,
      );

      return PackingItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Toggle packed status
  Future<PackingItemModel> togglePackedStatus(String id) async {
    try {
      final response = await _dioClient.post('${ApiConfig.packing}/$id/toggle');
      return PackingItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Bulk toggle packed status
  Future<void> bulkTogglePacked({
    required String tripId,
    required List<String> itemIds,
    required bool isPacked,
  }) async {
    try {
      await _dioClient.post(
        '${ApiConfig.packing}/bulk-toggle',
        queryParameters: {'trip_id': tripId},
        data: {
          'item_ids': itemIds,
          'is_packed': isPacked,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete packing item
  Future<void> deletePackingItem(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.packing}/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reorder packing items
  Future<void> reorderPackingItems({
    required String tripId,
    required List<ItemOrderData> itemOrders,
  }) async {
    try {
      await _dioClient.put(
        '${ApiConfig.packing}/reorder',
        queryParameters: {'trip_id': tripId},
        data: {
          'item_orders': itemOrders.map((e) => e.toJson()).toList(),
        },
      );
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
