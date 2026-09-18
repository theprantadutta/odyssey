import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/document_repository.dart';

part 'documents_provider.g.dart';

/// Documents state for a specific trip
class DocumentsState {
  final List<DocumentModel> documents;
  final List<DocumentsByType> groupedDocuments;
  final bool isLoading;
  final String? error;
  final int total;

  const DocumentsState({
    this.documents = const [],
    this.groupedDocuments = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  DocumentsState copyWith({
    List<DocumentModel>? documents,
    List<DocumentsByType>? groupedDocuments,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return DocumentsState(
      documents: documents ?? this.documents,
      groupedDocuments: groupedDocuments ?? this.groupedDocuments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// Document repository provider
@Riverpod(keepAlive: true)
DocumentRepository documentRepository(Ref ref) {
  return DocumentRepository();
}

/// Documents list provider for a specific trip
@Riverpod(keepAlive: true)
class TripDocuments extends _$TripDocuments {
  DocumentRepository get _documentRepository =>
      ref.read(documentRepositoryProvider);

  @override
  DocumentsState build(String tripId) {
    Future.microtask(() => _loadDocuments());
    return const DocumentsState(isLoading: true);
  }

  /// Load documents for the trip
  Future<void> _loadDocuments() async {
    AppLogger.state('Documents', 'Loading documents for trip: $tripId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _documentRepository.getDocuments(tripId: tripId);
      final grouped = await _documentRepository.getDocumentsGrouped(
        tripId: tripId,
      );

      AppLogger.state(
        'Documents',
        'Loaded ${response.documents.length} documents',
      );

      state = state.copyWith(
        documents: response.documents,
        groupedDocuments: grouped,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load documents: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh documents
  Future<void> refresh() async {
    await _loadDocuments();
  }

  /// The attempt that failed, kept so a retry of the same upload can replay it.
  ///
  /// A retry has to carry the id of the attempt it is retrying, or the server has
  /// no way to tell it apart from a new upload - which is how a lost response
  /// turns into two identical documents, each holding its own copy of the files
  /// against the owner's storage.
  ///
  /// Whether a press is a retry is decided from the request itself rather than
  /// from a flag the screen has to remember to set and reset. Pressing upload
  /// again on an unchanged draft is a retry; editing the name, the notes or the
  /// files makes it a different document, and reusing the id there would hand
  /// back the *old* one.
  ({String fingerprint, String operationId})? _failedAttempt;

  static String _fingerprintOf(
    String name,
    List<SelectedDocumentFile> files,
    String? type,
    String? notes,
  ) =>
      [
        name,
        type ?? '',
        notes ?? '',
        for (final file in files) '${file.file.path}:${file.fileName}',
      ].join('\u0000');

  /// Upload a new document with multiple files
  Future<void> uploadDocument({
    required String name,
    required List<SelectedDocumentFile> files,
    String? type,
    String? notes,
    ProgressCallback? onProgress,
  }) async {
    AppLogger.action('Uploading document: $name with ${files.length} file(s)');

    final fingerprint = _fingerprintOf(name, files, type, notes);

    final operationId = _failedAttempt?.fingerprint == fingerprint
        ? _failedAttempt!.operationId
        : const Uuid().v4();

    try {
      await _documentRepository.uploadDocument(
        tripId: tripId,
        name: name,
        files: files,
        operationId: operationId,
        type: type,
        notes: notes,
        onProgress: onProgress,
      );

      _failedAttempt = null;

      AppLogger.info('Document uploaded successfully');
      unawaited(ref.read(analyticsServiceProvider).trackDocumentUploaded(type: type ?? 'other'));

      // Reload to get updated grouped data
      await _loadDocuments();
    } catch (e) {
      // Remembered so the next press of an unchanged draft replays this attempt
      // instead of starting a second upload of the same files.
      _failedAttempt = (fingerprint: fingerprint, operationId: operationId);

      AppLogger.error('Failed to upload document: $e');
      rethrow;
    }
  }

  /// Update document metadata
  Future<void> updateDocument(String id, Map<String, dynamic> updates) async {
    AppLogger.action('Updating document: $id');

    try {
      final updatedDocument = await _documentRepository.updateDocument(
        id,
        updates,
      );

      AppLogger.info('Document updated successfully');

      // Update in list
      final updatedDocuments = state.documents.map((doc) {
        return doc.id == id ? updatedDocument : doc;
      }).toList();

      // Reload grouped data
      final grouped = await _documentRepository.getDocumentsGrouped(
        tripId: tripId,
      );

      state = state.copyWith(
        documents: updatedDocuments,
        groupedDocuments: grouped,
      );
    } catch (e) {
      AppLogger.error('Failed to update document: $e');
      rethrow;
    }
  }

  /// Delete document
  Future<void> deleteDocument(String id) async {
    AppLogger.action('Deleting document: $id');

    try {
      await _documentRepository.deleteDocument(id);

      final updatedDocuments = state.documents
          .where((doc) => doc.id != id)
          .toList();

      // Reload grouped data
      final grouped = await _documentRepository.getDocumentsGrouped(
        tripId: tripId,
      );

      AppLogger.info('Document deleted successfully');

      state = state.copyWith(
        documents: updatedDocuments,
        groupedDocuments: grouped,
        total: state.total - 1,
      );
    } catch (e) {
      AppLogger.error('Failed to delete document: $e');
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
