import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/memory_model.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/upload_outcome.dart';
import '../../data/repositories/memory_repository.dart';

part 'memories_provider.g.dart';

/// Memories state for a specific trip
class MemoriesState {
  final List<MemoryModel> memories;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final int total;

  /// The classified refusal, when the last upload failed.
  ///
  /// Carried alongside [error] because the message alone cannot tell the UI
  /// whether to offer "try again": retrying a quota refusal only wastes the
  /// user's data.
  final UploadFailure? uploadFailure;

  const MemoriesState({
    this.memories = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.total = 0,
    this.uploadFailure,
  });

  /// Whether offering the user a retry makes sense.
  bool get canRetryUpload => uploadFailure?.isRetryable ?? false;

  MemoriesState copyWith({
    List<MemoryModel>? memories,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    int? total,
    UploadFailure? uploadFailure,
  }) {
    return MemoriesState(
      memories: memories ?? this.memories,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      total: total ?? this.total,
      // Cleared alongside the error, so a stale refusal cannot keep offering a
      // retry for an upload that has since succeeded.
      uploadFailure: error == null ? null : (uploadFailure ?? this.uploadFailure),
    );
  }
}

/// Memory repository provider
@Riverpod(keepAlive: true)
MemoryRepository memoryRepository(Ref ref) {
  return MemoryRepository();
}

/// Memories list provider for a specific trip
@Riverpod(keepAlive: true)
class TripMemories extends _$TripMemories {
  MemoryRepository get _memoryRepository => ref.read(memoryRepositoryProvider);

  @override
  MemoriesState build(String tripId) {
    Future.microtask(() => _loadMemories());
    return const MemoriesState(isLoading: true);
  }

  /// Load memories for the trip
  Future<void> _loadMemories() async {
    AppLogger.state('Memories', 'Loading memories for trip: $tripId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _memoryRepository.getMemories(tripId: tripId);
      if (!ref.mounted) return;

      AppLogger.state(
        'Memories',
        'Loaded ${response.memories.length} memories',
      );

      state = state.copyWith(
        memories: response.memories,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to load memories: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh memories
  Future<void> refresh() async {
    await _loadMemories();
  }

  /// The attempt that failed, kept so a retry of the same upload can replay it.
  ///
  /// A retry has to carry the id of the attempt it is retrying, or the server has
  /// no way to tell it apart from a new upload - which is how a lost response
  /// turns into two identical memories.
  ///
  /// Whether a press is a retry is decided from the request itself rather than
  /// from a flag the screen has to remember to set and reset - nothing ever set
  /// it, so the id was regenerated on every press and the server could never
  /// recognise the retry. Pressing upload again on an unchanged draft is a retry;
  /// editing the caption or the selection makes it a different memory, and
  /// reusing the id there would hand back the *old* one.
  ({String fingerprint, String operationId})? _failedAttempt;

  static String _fingerprintOf(
    List<SelectedMediaFile>? mediaFiles,
    String? location,
    double? latitude,
    double? longitude,
    String? caption,
    DateTime? takenAt,
  ) =>
      [
        location ?? '',
        latitude?.toString() ?? '',
        longitude?.toString() ?? '',
        caption ?? '',
        takenAt?.toIso8601String() ?? '',
        for (final file in mediaFiles ?? const <SelectedMediaFile>[])
          '${file.file.path}:${file.fileName}',
      ].join('\u0000');

  /// Upload a new memory with media files.
  Future<void> uploadMemory({
    List<SelectedMediaFile>? mediaFiles,
    String? location,
    double? latitude,
    double? longitude,
    String? caption,
    DateTime? takenAt,
  }) async {
    AppLogger.action('Uploading memory');

    final fingerprint = _fingerprintOf(
        mediaFiles, location, latitude, longitude, caption, takenAt);

    final operationId = _failedAttempt?.fingerprint == fingerprint
        ? _failedAttempt!.operationId
        : const Uuid().v4();

    state = state.copyWith(isUploading: true, uploadProgress: 0.0, error: null);

    try {
      final newMemory = await _memoryRepository.uploadMemory(
        tripId: tripId,
        operationId: operationId,
        mediaFiles: mediaFiles,
        location: location,
        latitude: latitude,
        longitude: longitude,
        caption: caption,
        takenAt: takenAt,
        onProgress: (sent, total) {
          if (!ref.mounted) return;
          final progress = sent / total;
          state = state.copyWith(uploadProgress: progress);
        },
      );
      if (!ref.mounted) return;

      AppLogger.info('Memory uploaded successfully');
      final hasVideo = mediaFiles?.any((f) => f.isVideo) ?? false;
      unawaited(ref.read(analyticsServiceProvider).trackMemoryUploaded(
        mediaType: hasVideo ? 'video' : 'photo',
      ));

      // Add to list
      final updatedMemories = [newMemory, ...state.memories];

      // The attempt is settled, so the next upload is a new one.
      _failedAttempt = null;

      state = state.copyWith(
        memories: updatedMemories,
        total: state.total + 1,
        isUploading: false,
        uploadProgress: 1.0,
      );
    } on UploadFailure catch (failure) {
      if (!ref.mounted) return;
      AppLogger.error('Memory upload refused (${failure.kind.name}): $failure');

      // Remembered only on a retryable failure: the next press of an unchanged
      // draft then replays this attempt, so a response that was lost rather than
      // never sent resolves to the memory the server already created. A refusal
      // that will never succeed - no room on the plan - is not worth replaying.
      _failedAttempt = failure.isRetryable
          ? (fingerprint: fingerprint, operationId: operationId)
          : null;

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
        error: failure.message,
        uploadFailure: failure,
      );
      rethrow;
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to upload memory: $e');
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Delete memory
  Future<void> deleteMemory(String id) async {
    AppLogger.action('Deleting memory: $id');
    try {
      await _memoryRepository.deleteMemory(id);
      if (!ref.mounted) return;
      final updatedMemories = state.memories
          .where((memory) => memory.id != id)
          .toList();
      AppLogger.info('Memory deleted successfully');
      state = state.copyWith(memories: updatedMemories, total: state.total - 1);
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to delete memory: $e');
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Single memory provider (for detail/viewer)
@Riverpod(keepAlive: true)
class Memory extends _$Memory {
  MemoryRepository get _memoryRepository => ref.read(memoryRepositoryProvider);

  @override
  Future<MemoryModel?> build(String memoryId) async {
    return await _loadMemory(memoryId);
  }

  Future<MemoryModel?> _loadMemory(String memoryId) async {
    try {
      return await _memoryRepository.getMemoryById(memoryId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh single memory
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadMemory(memoryId));
  }
}
