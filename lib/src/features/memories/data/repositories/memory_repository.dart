import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/memory_model.dart';

/// Memory repository for API calls with file upload support
class MemoryRepository {
  final DioClient _dioClient = DioClient();

  /// Get all memories for a trip
  Future<MemoriesResponse> getMemories({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.memories,
        queryParameters: {'trip_id': tripId},
      );

      return MemoriesResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get memory by ID
  Future<MemoryModel> getMemoryById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.memories}/$id');
      return MemoryModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload a new memory with photo
  Future<MemoryModel> uploadMemory({
    required String tripId,
    required File photoFile,
    required double latitude,
    required double longitude,
    String? caption,
    DateTime? takenAt,
    ProgressCallback? onProgress,
  }) async {
    try {
      final fileName = photoFile.path.split('/').last;

      final formData = FormData.fromMap({
        'trip_id': tripId,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'photo': await MultipartFile.fromFile(
          photoFile.path,
          filename: fileName,
        ),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      });

      final response = await _dioClient.multipart(
        '${ApiConfig.memories}/',
        formData,
        onSendProgress: onProgress,
      );

      return MemoryModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete memory
  Future<void> deleteMemory(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.memories}/$id');
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
