import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
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

/// Document repository - local-first metadata with online file uploads
class DocumentRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all documents for a trip - reads from local DB, triggers background API refresh
  Future<DocumentsResponse> getDocuments({
    required String tripId,
    String? type,
  }) async {
    final localDocs = await _db.documentsDao.getByTrip(tripId);

    if (localDocs.isNotEmpty || !ConnectivityService().isOnline) {
      var documents = localDocs.map(documentFromLocal).toList();

      if (type != null) {
        documents = documents.where((d) => d.type == type).toList();
      }

      if (ConnectivityService().isOnline) {
        _refreshFromApi(tripId);
      }

      return DocumentsResponse(documents: documents, total: documents.length);
    }

    // No local data - fetch from API
    return _fetchFromApi(tripId: tripId, type: type);
  }

  /// Get documents grouped by type - local computation with API fallback
  Future<List<DocumentsByType>> getDocumentsGrouped({
    required String tripId,
  }) async {
    final localDocs = await _db.documentsDao.getByTrip(tripId);

    if (localDocs.isNotEmpty || !ConnectivityService().isOnline) {
      final documents = localDocs.map(documentFromLocal).toList();

      // Group by type locally
      final typeMap = <String, List<DocumentModel>>{};
      for (final doc in documents) {
        typeMap.putIfAbsent(doc.type, () => []).add(doc);
      }

      if (ConnectivityService().isOnline) {
        _refreshFromApi(tripId);
      }

      return typeMap.entries.map((entry) => DocumentsByType(
        type: entry.key,
        documents: entry.value,
        count: entry.value.length,
      )).toList();
    }

    try {
      final response = await _dioClient.get(
        '${ApiConfig.documents}/grouped',
        queryParameters: {'trip_id': tripId},
      );

      final grouped = (response.data as List)
          .map((json) => DocumentsByType.fromJson(json))
          .toList();

      // Cache all documents locally
      for (final group in grouped) {
        for (final doc in group.documents) {
          await _db.documentsDao.upsert(documentToLocal(doc));
        }
      }

      return grouped;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get document by ID - reads from local DB first
  Future<DocumentModel> getDocumentById(String id) async {
    final local = await _db.documentsDao.getById(id);
    if (local != null && !local.isDeleted) {
      if (ConnectivityService().isOnline) {
        _refreshDocumentFromApi(id);
      }
      return documentFromLocal(local);
    }

    try {
      final response = await _dioClient.get('${ApiConfig.documents}/$id');
      final doc = DocumentModel.fromJson(response.data);
      await _db.documentsDao.upsert(documentToLocal(doc));
      return doc;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a document with a pre-uploaded file URL - local-first metadata
  Future<DocumentModel> createDocument(DocumentRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final doc = DocumentModel(
      id: id,
      tripId: request.tripId,
      type: request.type,
      name: request.name,
      fileUrl: request.fileUrl,
      fileType: request.fileType,
      notes: request.notes,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    await _db.documentsDao.upsert(documentToLocal(doc, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'document',
      entityId: id,
      operation: 'create',
      payload: request.toJson(),
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post('${ApiConfig.documents}/', data: request.toJson());
        final serverDoc = DocumentModel.fromJson(response.data);
        await _db.documentsDao.upsert(documentToLocal(serverDoc));
        await _db.syncQueueDao.removeForEntity('document', id);
        return serverDoc;
      } catch (e) {
        AppLogger.warning('Failed to sync document create, will retry: $e');
      }
    }

    return doc;
  }

  /// Upload a document with multiple files - online only (files need uploading)
  Future<DocumentModel> uploadDocument({
    required String tripId,
    required String name,
    required List<SelectedDocumentFile> files,
    String? type,
    String? notes,
    ProgressCallback? onProgress,
  }) async {
    if (name.isEmpty) throw 'Document name is required';
    if (files.isEmpty) throw 'At least one file is required';
    if (files.length > maxFilesPerDocument) {
      throw 'Maximum $maxFilesPerDocument files allowed per document';
    }

    for (final file in files) {
      final fileSize = await file.file.length();
      if (fileSize > maxDocumentFileSizeBytes) {
        throw 'File "${file.fileName}" exceeds maximum size of ${maxDocumentFileSizeBytes ~/ (1024 * 1024)}MB';
      }
    }

    try {
      final formMap = <String, dynamic>{
        'trip_id': tripId,
        'name': name,
        'type': type ?? 'other',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

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

      final serverDoc = DocumentModel.fromJson(response.data);

      // Cache in local DB
      await _db.documentsDao.upsert(documentToLocal(serverDoc));

      return serverDoc;
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
        options: Options(contentType: 'multipart/form-data'),
      );

      final serverDoc = DocumentModel.fromJson(response.data);
      await _db.documentsDao.upsert(documentToLocal(serverDoc));
      return serverDoc;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update document metadata - writes to local DB immediately, syncs in background
  Future<DocumentModel> updateDocument(String id, Map<String, dynamic> updates) async {
    final existing = await _db.documentsDao.getById(id);
    if (existing != null) {
      final updatedCompanion = LocalDocumentsCompanion(
        id: Value(id),
        type: updates.containsKey('type') ? Value(updates['type'] as String) : const Value.absent(),
        name: updates.containsKey('name') ? Value(updates['name'] as String) : const Value.absent(),
        files: updates.containsKey('files') ? Value(jsonEncode(updates['files'])) : const Value.absent(),
        notes: updates.containsKey('notes') ? Value(updates['notes'] as String?) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localDocuments))..where((t) => t.id.equals(id))).write(updatedCompanion);
    }

    await SyncQueueService().enqueue(
      entityType: 'document',
      entityId: id,
      operation: 'update',
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch('${ApiConfig.documents}/$id', data: updates);
        final serverDoc = DocumentModel.fromJson(response.data);
        await _db.documentsDao.upsert(documentToLocal(serverDoc));
        await _db.syncQueueDao.removeForEntity('document', id);
        return serverDoc;
      } catch (e) {
        AppLogger.warning('Failed to sync document update, will retry: $e');
      }
    }

    final updated = await _db.documentsDao.getById(id);
    return updated != null ? documentFromLocal(updated) : throw 'Document not found';
  }

  /// Delete document - soft deletes locally, syncs in background
  Future<void> deleteDocument(String id) async {
    await _db.documentsDao.softDelete(id);

    await SyncQueueService().enqueue(
      entityType: 'document',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.documents}/$id');
        await _db.documentsDao.hardDelete(id);
        await _db.syncQueueDao.removeForEntity('document', id);
      } catch (e) {
        AppLogger.warning('Failed to sync document delete, will retry: $e');
      }
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<DocumentsResponse> _fetchFromApi({
    required String tripId,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{'trip_id': tripId};
      if (type != null) queryParams['type'] = type;

      final response = await _dioClient.get(ApiConfig.documents, queryParameters: queryParams);
      final docsResponse = DocumentsResponse.fromJson(response.data);

      for (final doc in docsResponse.documents) {
        await _db.documentsDao.upsert(documentToLocal(doc));
      }

      return docsResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.documents,
        queryParameters: {'trip_id': tripId},
      );
      final docsResponse = DocumentsResponse.fromJson(response.data);
      for (final doc in docsResponse.documents) {
        final existing = await _db.documentsDao.getById(doc.id);
        if (existing == null || !existing.isDirty) {
          await _db.documentsDao.upsert(documentToLocal(doc));
        }
      }
    } catch (e) {
      AppLogger.warning('Background document refresh failed: $e');
    }
  }

  void _refreshDocumentFromApi(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.documents}/$id');
      final doc = DocumentModel.fromJson(response.data);
      final existing = await _db.documentsDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await _db.documentsDao.upsert(documentToLocal(doc));
      }
    } catch (e) {
      AppLogger.warning('Background document detail refresh failed: $e');
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
