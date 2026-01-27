import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../packing/data/models/packing_model.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../../packing/presentation/screens/packing_item_form_screen.dart';
import '../../../packing/presentation/widgets/packing_list_widget.dart';
import '../../../packing/presentation/widgets/packing_progress_indicator.dart';

class TripPackingTab extends ConsumerWidget {
  final String tripId;

  const TripPackingTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final packingState = ref.watch(tripPackingProvider(tripId));

    return Stack(
      children: [
        // Main content
        _buildContent(context, ref, packingState, theme, colorScheme),
        // FAB
        Positioned(
          right: AppSizes.space16,
          bottom: AppSizes.space16,
          child: _buildFAB(context),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    PackingState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Loading state
    if (state.isLoading && state.items.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (state.error != null && state.items.isEmpty) {
      return _buildErrorState(context, ref, state.error!, colorScheme);
    }

    // Empty state
    if (state.items.isEmpty) {
      return NoPackingItemsState(
        onAddItem: () => _navigateToAddItem(context),
      );
    }

    // Packing list
    return RefreshIndicator(
      color: AppColors.oceanTeal,
      onRefresh: () async {
        await ref.read(tripPackingProvider(tripId).notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSizes.space80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            PackingProgressIndicator(
              total: state.total,
              packed: state.packedCount,
              progress: state.progress,
            ),

            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items',
                    style: AppTypography.titleSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showQuickAddSheet(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space12,
                          vertical: AppSizes.space8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.oceanTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: AppColors.oceanTeal,
                            ),
                            const SizedBox(width: AppSizes.space4),
                            Text(
                              'Quick Add',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.oceanTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space12),

            // Packing list grouped by category
            PackingListWidget(
              items: state.items,
              onToggle: (item) {
                ref
                    .read(tripPackingProvider(tripId).notifier)
                    .togglePackedStatus(item.id);
              },
              onItemTap: (item) => _navigateToEditItem(context, item),
              onDelete: (item) => _showDeleteDialog(context, ref, item),
              onBulkToggle: (category, isPacked) {
                ref
                    .read(tripPackingProvider(tripId).notifier)
                    .bulkToggleCategory(category, isPacked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OrbitalLoader(size: 64),
          const SizedBox(height: 20),
          Text(
            'Loading packing list...',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load packing list',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(tripPackingProvider(tripId).notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.oceanTeal,
                backgroundColor: AppColors.oceanTeal.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space20,
                  vertical: AppSizes.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToAddItem(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.oceanTeal,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.oceanTeal.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  void _navigateToAddItem(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PackingItemFormScreen(tripId: tripId),
      ),
    );
  }

  void _navigateToEditItem(BuildContext context, PackingItemModel item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PackingItemFormScreen(
          tripId: tripId,
          item: item,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    PackingItemModel item,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Item',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"?',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
              try {
                await ref
                    .read(tripPackingProvider(tripId).notifier)
                    .deletePackingItem(item.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: AppSizes.space12),
                          Text('Item deleted'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (context) => _QuickAddSheet(
        tripId: tripId,
        onItemAdded: () {
          ref.read(tripPackingProvider(tripId).notifier).refresh();
        },
      ),
    );
  }
}

/// Quick add sheet for common items
class _QuickAddSheet extends ConsumerStatefulWidget {
  final String tripId;
  final VoidCallback onItemAdded;

  const _QuickAddSheet({
    required this.tripId,
    required this.onItemAdded,
  });

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final TextEditingController _controller = TextEditingController();
  PackingCategory _selectedCategory = PackingCategory.other;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.space20,
        right: AppSizes.space20,
        top: AppSizes.space20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.space20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.space20),

          Text(
            'Quick Add Item',
            style: AppTypography.titleMedium.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.space16),

          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PackingCategory.values.map((category) {
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.space8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space12,
                        vertical: AppSizes.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.oceanTeal
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(category.icon),
                          const SizedBox(width: AppSizes.space4),
                          Text(
                            category.displayName,
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSizes.space16),

          // Text input with add button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  style: AppTypography.bodyLarge.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Item name...',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSizes.space16),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              GestureDetector(
                onTap: _addItem,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.oceanTeal,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty) return;

    HapticFeedback.mediumImpact();

    try {
      await ref.read(tripPackingProvider(widget.tripId).notifier).createPackingItem(
            PackingItemRequest(
              tripId: widget.tripId,
              name: _controller.text.trim(),
              category: _selectedCategory.name,
            ),
          );

      _controller.clear();
      widget.onItemAdded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: AppSizes.space12),
                Text('Item added'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }
}
