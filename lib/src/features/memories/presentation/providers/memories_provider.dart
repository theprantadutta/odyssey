import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/memory_model.dart';
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

  const MemoriesState({
    this.memories = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.total = 0,
  });

  MemoriesState copyWith({
    List<MemoryModel>? memories,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    int? total,
  }) {
    return MemoriesState(
      memories: memories ?? this.memories,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// Memory repository provider
@riverpod
MemoryRepository memoryRepository(Ref ref) {
  return MemoryRepository();
}

/// Memories list provider for a specific trip
@riverpod
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

      AppLogger.state(
          'Memories', 'Loaded ${response.memories.length} memories');

      state = state.copyWith(
        memories: response.memories,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load memories: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh memories
  Future<void> refresh() async {
    await _loadMemories();
  }

  /// Upload a new memory with photo
  Future<void> uploadMemory({
    required File photoFile,
    required double latitude,
    required double longitude,
    String? caption,
    DateTime? takenAt,
  }) async {
    AppLogger.action('Uploading memory photo');
    state = state.copyWith(isUploading: true, uploadProgress: 0.0, error: null);

    try {
      final newMemory = await _memoryRepository.uploadMemory(
        tripId: tripId,
        photoFile: photoFile,
        latitude: latitude,
        longitude: longitude,
        caption: caption,
        takenAt: takenAt,
        onProgress: (sent, total) {
          final progress = sent / total;
          state = state.copyWith(uploadProgress: progress);
        },
      );

      AppLogger.info('Memory uploaded successfully');

      // Add to list
      final updatedMemories = [newMemory, ...state.memories];

      state = state.copyWith(
        memories: updatedMemories,
        total: state.total + 1,
        isUploading: false,
        uploadProgress: 1.0,
      );
    } catch (e) {
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
      final updatedMemories =
          state.memories.where((memory) => memory.id != id).toList();
      AppLogger.info('Memory deleted successfully');
      state = state.copyWith(
        memories: updatedMemories,
        total: state.total - 1,
      );
    } catch (e) {
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
@riverpod
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
