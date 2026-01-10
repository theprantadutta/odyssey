import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/packing_model.dart';
import '../../data/repositories/packing_repository.dart';

part 'packing_provider.g.dart';

/// Packing state for a specific trip
class PackingState {
  final List<PackingItemModel> items;
  final bool isLoading;
  final String? error;
  final int total;
  final int packedCount;
  final int unpackedCount;
  final PackingProgressResponse? progress;

  const PackingState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.packedCount = 0,
    this.unpackedCount = 0,
    this.progress,
  });

  /// Get items grouped by category
  Map<String, List<PackingItemModel>> get itemsByCategory {
    final grouped = <String, List<PackingItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// Get progress percentage
  double get progressPercent {
    if (total == 0) return 0.0;
    return (packedCount / total) * 100;
  }

  PackingState copyWith({
    List<PackingItemModel>? items,
    bool? isLoading,
    String? error,
    int? total,
    int? packedCount,
    int? unpackedCount,
    PackingProgressResponse? progress,
  }) {
    return PackingState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      packedCount: packedCount ?? this.packedCount,
      unpackedCount: unpackedCount ?? this.unpackedCount,
      progress: progress ?? this.progress,
    );
  }
}

/// Packing repository provider
@Riverpod(keepAlive: true)
PackingRepository packingRepository(Ref ref) {
  return PackingRepository();
}

/// Packing list provider for a specific trip
@Riverpod(keepAlive: true)
class TripPacking extends _$TripPacking {
  PackingRepository get _packingRepository =>
      ref.read(packingRepositoryProvider);

  @override
  PackingState build(String tripId) {
    Future.microtask(() => _loadPackingItems());
    return const PackingState(isLoading: true);
  }

  /// Load packing items for the trip
  Future<void> _loadPackingItems() async {
    AppLogger.state('Packing', 'Loading packing items for trip: $tripId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _packingRepository.getPackingItems(tripId: tripId);
      if (!ref.mounted) return;
      final progress = await _packingRepository.getPackingProgress(
        tripId: tripId,
      );
      if (!ref.mounted) return;

      AppLogger.state(
        'Packing',
        'Loaded ${response.items.length} packing items',
      );

      state = state.copyWith(
        items: response.items,
        total: response.total,
        packedCount: response.packedCount,
        unpackedCount: response.unpackedCount,
        progress: progress,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to load packing items: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh packing items
  Future<void> refresh() async {
    await _loadPackingItems();
  }

  /// Create a new packing item
  Future<void> createPackingItem(PackingItemRequest request) async {
    AppLogger.action('Creating packing item');

    try {
      final newItem = await _packingRepository.createPackingItem(request);
      if (!ref.mounted) return;

      AppLogger.info('Packing item created successfully');

      // Add to list
      final updatedItems = [...state.items, newItem];

      // Reload progress
      final progress = await _packingRepository.getPackingProgress(
        tripId: tripId,
      );
      if (!ref.mounted) return;

      state = state.copyWith(
        items: updatedItems,
        total: state.total + 1,
        unpackedCount: state.unpackedCount + 1,
        progress: progress,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to create packing item: $e');
      rethrow;
    }
  }

  /// Update packing item
  Future<void> updatePackingItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    AppLogger.action('Updating packing item: $id');

    try {
      final updatedItem = await _packingRepository.updatePackingItem(
        id,
        updates,
      );
      if (!ref.mounted) return;

      AppLogger.info('Packing item updated successfully');

      // Update in list
      final updatedItems = state.items.map((item) {
        return item.id == id ? updatedItem : item;
      }).toList();

      // Reload progress
      final progress = await _packingRepository.getPackingProgress(
        tripId: tripId,
      );
      if (!ref.mounted) return;

      state = state.copyWith(items: updatedItems, progress: progress);
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to update packing item: $e');
      rethrow;
    }
  }

  /// Toggle packed status for an item
  Future<void> togglePackedStatus(String id) async {
    AppLogger.action('Toggling packed status: $id');

    // Optimistic update
    final currentItem = state.items.firstWhere((item) => item.id == id);
    final optimisticItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isPacked: !item.isPacked);
      }
      return item;
    }).toList();

    final newPackedCount = currentItem.isPacked
        ? state.packedCount - 1
        : state.packedCount + 1;
    final newUnpackedCount = currentItem.isPacked
        ? state.unpackedCount + 1
        : state.unpackedCount - 1;

    state = state.copyWith(
      items: optimisticItems,
      packedCount: newPackedCount,
      unpackedCount: newUnpackedCount,
    );

    try {
      final updatedItem = await _packingRepository.togglePackedStatus(id);
      if (!ref.mounted) return;

      // Update with server response
      final updatedItems = state.items.map((item) {
        return item.id == id ? updatedItem : item;
      }).toList();

      // Reload progress for accurate category breakdown
      final progress = await _packingRepository.getPackingProgress(
        tripId: tripId,
      );
      if (!ref.mounted) return;

      AppLogger.info('Packed status toggled successfully');

      state = state.copyWith(items: updatedItems, progress: progress);
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to toggle packed status: $e');
      // Revert optimistic update
      await _loadPackingItems();
      rethrow;
    }
  }

  /// Bulk toggle packed status for all items in a category
  Future<void> bulkToggleCategory(String category, bool isPacked) async {
    AppLogger.action('Bulk toggling category: $category to $isPacked');

    final categoryItemIds = state.items
        .where((item) => item.category == category)
        .map((item) => item.id)
        .toList();

    if (categoryItemIds.isEmpty) return;

    try {
      await _packingRepository.bulkTogglePacked(
        tripId: tripId,
        itemIds: categoryItemIds,
        isPacked: isPacked,
      );
      if (!ref.mounted) return;

      AppLogger.info('Bulk toggle successful');

      // Reload to get updated state
      await _loadPackingItems();
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to bulk toggle: $e');
      rethrow;
    }
  }

  /// Delete packing item
  Future<void> deletePackingItem(String id) async {
    AppLogger.action('Deleting packing item: $id');

    try {
      final itemToDelete = state.items.firstWhere((item) => item.id == id);

      await _packingRepository.deletePackingItem(id);
      if (!ref.mounted) return;

      final updatedItems = state.items.where((item) => item.id != id).toList();

      // Update counts
      final newPackedCount = itemToDelete.isPacked
          ? state.packedCount - 1
          : state.packedCount;
      final newUnpackedCount = itemToDelete.isPacked
          ? state.unpackedCount
          : state.unpackedCount - 1;

      // Reload progress
      final progress = await _packingRepository.getPackingProgress(
        tripId: tripId,
      );
      if (!ref.mounted) return;

      AppLogger.info('Packing item deleted successfully');

      state = state.copyWith(
        items: updatedItems,
        total: state.total - 1,
        packedCount: newPackedCount,
        unpackedCount: newUnpackedCount,
        progress: progress,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to delete packing item: $e');
      rethrow;
    }
  }

  /// Reorder items within a category
  Future<void> reorderItems(List<PackingItemModel> reorderedItems) async {
    AppLogger.action('Reordering packing items');

    // Update local state immediately
    final itemOrders = reorderedItems.asMap().entries.map((entry) {
      return ItemOrderData(id: entry.value.id, sortOrder: entry.key);
    }).toList();

    try {
      await _packingRepository.reorderPackingItems(
        tripId: tripId,
        itemOrders: itemOrders,
      );
      if (!ref.mounted) return;

      AppLogger.info('Items reordered successfully');

      // Reload to get updated state
      await _loadPackingItems();
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to reorder items: $e');
      await _loadPackingItems();
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
