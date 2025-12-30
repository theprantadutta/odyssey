import 'package:riverpod_annotation/riverpod_annotation.dart';
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
@riverpod
DocumentRepository documentRepository(Ref ref) {
  return DocumentRepository();
}

/// Documents list provider for a specific trip
@riverpod
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
      final grouped =
          await _documentRepository.getDocumentsGrouped(tripId: tripId);

      AppLogger.state('Documents', 'Loaded ${response.documents.length} documents');

      state = state.copyWith(
        documents: response.documents,
        groupedDocuments: grouped,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load documents: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh documents
  Future<void> refresh() async {
    await _loadDocuments();
  }

  /// Upload a new document
  Future<void> uploadDocument({
    required String name,
    required String type,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
  }) async {
    AppLogger.action('Uploading document: $name');

    try {
      await _documentRepository.uploadDocument(
        tripId: tripId,
        name: name,
        type: type,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        notes: notes,
      );

      AppLogger.info('Document uploaded successfully');

      // Reload to get updated grouped data
      await _loadDocuments();
    } catch (e) {
      AppLogger.error('Failed to upload document: $e');
      rethrow;
    }
  }

  /// Update document metadata
  Future<void> updateDocument(String id, Map<String, dynamic> updates) async {
    AppLogger.action('Updating document: $id');

    try {
      final updatedDocument =
          await _documentRepository.updateDocument(id, updates);

      AppLogger.info('Document updated successfully');

      // Update in list
      final updatedDocuments = state.documents.map((doc) {
        return doc.id == id ? updatedDocument : doc;
      }).toList();

      // Reload grouped data
      final grouped =
          await _documentRepository.getDocumentsGrouped(tripId: tripId);

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

      final updatedDocuments =
          state.documents.where((doc) => doc.id != id).toList();

      // Reload grouped data
      final grouped =
          await _documentRepository.getDocumentsGrouped(tripId: tripId);

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
