import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/document_model.dart';

/// Progress callback for file uploads
typedef ProgressCallback = void Function(int sent, int total);

/// Represents a selected document file for upload
class SelectedDocumentFile {
  final File file;
  final String fileName;
  final String? mimeType;

  const SelectedDocumentFile({
    required this.file,
    required this.fileName,
    this.mimeType,
  });

  /// Get MIME type from file extension if not specified
  String get effectiveMimeType {
    if (mimeType != null) return mimeType!;

    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Maximum file size for documents (10MB)
const int maxDocumentFileSizeBytes = 10 * 1024 * 1024;

/// Maximum number of files per document
const int maxFilesPerDocument = 10;

/// Document repository for API calls
class DocumentRepository {
  final DioClient _dioClient = DioClient();

  /// Get all documents for a trip
  Future<DocumentsResponse> getDocuments({
    required String tripId,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await _dioClient.get(
        ApiConfig.documents,
        queryParameters: queryParams,
      );

      return DocumentsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get documents grouped by type
  Future<List<DocumentsByType>> getDocumentsGrouped({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.get(
        '${ApiConfig.documents}/grouped',
        queryParameters: {'trip_id': tripId},
      );

      return (response.data as List)
          .map((json) => DocumentsByType.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get document by ID
  Future<DocumentModel> getDocumentById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.documents}/$id');
      return DocumentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a document with a pre-uploaded file URL
  Future<DocumentModel> createDocument(DocumentRequest request) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.documents}/',
        data: request.toJson(),
      );

      return DocumentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload a document with multiple files
  Future<DocumentModel> uploadDocument({
    required String tripId,
    required String name,
    required List<SelectedDocumentFile> files,
    String? type,
    String? notes,
    ProgressCallback? onProgress,
  }) async {
    // Validate inputs
    if (name.isEmpty) {
      throw 'Document name is required';
    }
    if (files.isEmpty) {
      throw 'At least one file is required';
    }
    if (files.length > maxFilesPerDocument) {
      throw 'Maximum $maxFilesPerDocument files allowed per document';
    }

    // Validate file sizes
    for (final file in files) {
      final fileSize = await file.file.length();
      if (fileSize > maxDocumentFileSizeBytes) {
        throw 'File "${file.fileName}" exceeds maximum size of ${maxDocumentFileSizeBytes ~/ (1024 * 1024)}MB';
      }
    }

    try {
      // Build form data with multiple files
      final formMap = <String, dynamic>{
        'trip_id': tripId,
        'name': name,
        'type': type ?? 'other',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      // Add files to form data
      final filesList = <MultipartFile>[];
      for (final file in files) {
        filesList.add(
          await MultipartFile.fromFile(
            file.file.path,
            filename: file.fileName,
            contentType: MediaType.parse(file.effectiveMimeType),
          ),
        );
      }
      formMap['files'] = filesList;

      final formData = FormData.fromMap(formMap);

      final response = await _dioClient.multipart(
        ApiConfig.documents,
        formData,
        onSendProgress: onProgress,
      );

      return DocumentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload a single document file (legacy method for backward compatibility)
  Future<DocumentModel> uploadSingleDocument({
    required String tripId,
    required String name,
    required String type,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'trip_id': tripId,
        'name': name,
        'type': type,
        if (notes != null) 'notes': notes,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await _dioClient.post(
        ApiConfig.documents,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return DocumentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update document metadata
  Future<DocumentModel> updateDocument(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConfig.documents}/$id',
        data: updates,
      );

      return DocumentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete document
  Future<void> deleteDocument(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.documents}/$id');
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
