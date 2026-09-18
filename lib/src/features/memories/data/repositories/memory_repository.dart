import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import 'package:uuid/uuid.dart';
import '../models/upload_outcome.dart';
import '../models/memory_model.dart';

/// Selected media file with type information
class SelectedMediaFile {
  final File file;
  final bool isVideo;
  final String fileName;

  SelectedMediaFile({
    required this.file,
    required this.isVideo,
    String? fileName,
  }) : fileName = fileName ?? file.path.split(Platform.pathSeparator).last;
}

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

  /// Upload a new memory with multiple media files (photos and/or videos)
  /// At least caption or one file must be provided
  /// [operationId] identifies this upload attempt and must stay the same across
  /// retries. The server resolves a repeat to the memory it already created, so a
  /// lost response costs one request instead of a second full upload and a
  /// duplicate memory. Callers that retry must pass the id they used the first
  /// time; omitting it generates a fresh one, which is right for a new attempt.
  Future<MemoryModel> uploadMemory({
    required String tripId,
    String? operationId,
    List<SelectedMediaFile>? mediaFiles,
    String? location,
    double? latitude,
    double? longitude,
    String? caption,
    DateTime? takenAt,
    ProgressCallback? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'trip_id': tripId,
        'operation_id': operationId ?? const Uuid().v4(),
        if (location != null && location.isNotEmpty) 'location': location,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      });

      // Add multiple files if provided
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        for (final mediaFile in mediaFiles) {
          formData.files.add(MapEntry(
            'files',
            await MultipartFile.fromFile(
              mediaFile.file.path,
              filename: mediaFile.fileName,
            ),
          ));
        }
      }

      final response = await _dioClient.multipart(
        '${ApiConfig.memories}/',
        formData,
        onSendProgress: onProgress,
      );

      return MemoryModel.fromJson(response.data);
    } on DioException catch (e) {
      // Classified rather than flattened to a string: the caller has to be able
      // to tell "try again" from "this will never work until you free up space".
      throw UploadFailure.fromResponse(
        statusCode: e.response?.statusCode,
        body: e.response?.data is Map<String, dynamic>
            ? e.response!.data as Map<String, dynamic>
            : null,
        fallbackMessage: _handleError(e),
      );
    }
  }

  /// Legacy method for backward compatibility - upload single photo
  Future<MemoryModel> uploadMemoryLegacy({
    required String tripId,
    required File photoFile,
    required double latitude,
    required double longitude,
    String? caption,
    DateTime? takenAt,
    ProgressCallback? onProgress,
  }) async {
    return uploadMemory(
      tripId: tripId,
      mediaFiles: [
        SelectedMediaFile(file: photoFile, isVideo: false),
      ],
      latitude: latitude,
      longitude: longitude,
      caption: caption,
      takenAt: takenAt,
      onProgress: onProgress,
    );
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
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
