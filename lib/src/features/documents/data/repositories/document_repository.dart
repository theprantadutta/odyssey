import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/document_model.dart';

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

  /// Upload a document file directly
  Future<DocumentModel> uploadDocument({
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
        '${ApiConfig.documents}/upload',
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
