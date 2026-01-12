import 'dart:io';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../config/api_config.dart';

/// Response model for file upload
class FileUploadResponse {
  final String url;
  final String fileName;
  final int fileSizeBytes;
  final String? contentType;

  FileUploadResponse({
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    this.contentType,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      url: json['url'] as String,
      fileName: json['file_name'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      contentType: json['content_type'] as String?,
    );
  }
}

/// Service for uploading files to the backend
class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  final DioClient _dioClient = DioClient();

  /// Upload an image file
  ///
  /// [file] - The image file to upload
  /// [folder] - Optional folder path on the server (default: "uploads")
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns [FileUploadResponse] with the uploaded file URL and metadata
  Future<FileUploadResponse> uploadImage({
    required File file,
    String folder = 'uploads',
    ProgressCallback? onProgress,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'folder': folder,
      });

      final response = await _dioClient.multipart(
        ApiConfig.fileUpload,
        formData,
        onSendProgress: onProgress,
      );

      return FileUploadResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload cover image specifically
  ///
  /// A convenience method for uploading trip cover images
  Future<FileUploadResponse> uploadCoverImage({
    required File file,
    ProgressCallback? onProgress,
  }) async {
    return uploadImage(
      file: file,
      folder: 'covers',
      onProgress: onProgress,
    );
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    return error.message ?? 'Failed to upload file';
  }
}
