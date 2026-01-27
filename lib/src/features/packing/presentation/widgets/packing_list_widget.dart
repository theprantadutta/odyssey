import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/packing_model.dart';
import 'packing_item_tile.dart';

/// Widget displaying packing items grouped by category
class PackingListWidget extends StatelessWidget {
  final List<PackingItemModel> items;
  final Function(PackingItemModel) onToggle;
  final Function(PackingItemModel)? onItemTap;
  final Function(PackingItemModel)? onDelete;
  final Function(String category, bool isPacked)? onBulkToggle;

  const PackingListWidget({
    super.key,
    required this.items,
    required this.onToggle,
    this.onItemTap,
    this.onDelete,
    this.onBulkToggle,
  });

  Map<String, List<PackingItemModel>> get _itemsByCategory {
    final grouped = <String, List<PackingItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    // Sort items within each category by sort_order
    for (final category in grouped.keys) {
      grouped[category]!.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _itemsByCategory;

    // Sort categories in a consistent order
    final orderedCategories = [
      'clothes',
      'toiletries',
      'electronics',
      'documents',
      'medicine',
      'other',
    ].where((cat) => categories.containsKey(cat)).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      itemCount: orderedCategories.length,
      itemBuilder: (context, index) {
        final category = orderedCategories[index];
        final categoryItems = categories[category]!;
        return _CategorySection(
          category: category,
          items: categoryItems,
          onToggle: onToggle,
          onItemTap: onItemTap,
          onDelete: onDelete,
          onBulkToggle: onBulkToggle != null
              ? (isPacked) => onBulkToggle!(category, isPacked)
              : null,
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<PackingItemModel> items;
  final Function(PackingItemModel) onToggle;
  final Function(PackingItemModel)? onItemTap;
  final Function(PackingItemModel)? onDelete;
  final Function(bool isPacked)? onBulkToggle;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onToggle,
    this.onItemTap,
    this.onDelete,
    this.onBulkToggle,
  });

  int get packedCount => items.where((item) => item.isPacked).length;
  bool get allPacked => packedCount == items.length;
  bool get anyPacked => packedCount > 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final packingCategory = PackingCategory.fromString(category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          GestureDetector(
            onTap: onBulkToggle != null
                ? () {
                    HapticFeedback.lightImpact();
                    onBulkToggle!(!allPacked);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space12,
              ),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                children: [
                  Text(
                    packingCategory.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          packingCategory.displayName,
                          style: AppTypography.titleSmall.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$packedCount of ${items.length} packed',
                          style: AppTypography.bodySmall.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator
                  _buildCategoryProgress(),
                  // Bulk toggle button
                  if (onBulkToggle != null) ...[
                    const SizedBox(width: AppSizes.space8),
                    Icon(
                      allPacked
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                      size: 20,
                      color: _getCategoryColor(category),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSizes.space12),

          // Items list
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space8),
                child: PackingItemTile(
                  item: item,
                  onToggle: () => onToggle(item),
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                  onDelete: onDelete != null ? () => onDelete!(item) : null,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryProgress() {
    final progress = items.isEmpty ? 0.0 : packedCount / items.length;
    final color = _getCategoryColor(category);

    return Container(
      width: 48,
      height: 6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'clothes':
        return AppColors.coralPink;
      case 'toiletries':
        return AppColors.skyBlue;
      case 'electronics':
        return AppColors.sunnyYellow;
      case 'documents':
        return AppColors.lavenderDream;
      case 'medicine':
        return AppColors.mintGreen;
      default:
        return AppColors.slate;
    }
  }
}

/// Empty state for packing list
class NoPackingItemsState extends StatelessWidget {
  final VoidCallback? onAddItem;

  const NoPackingItemsState({
    super.key,
    this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Center(
                child: Text(
                  '🧳',
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'No packing items yet',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Add items to your packing list to stay organized',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddItem != null) ...[
              const SizedBox(height: AppSizes.space24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onAddItem!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.oceanTeal,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.oceanTeal.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Text(
                        'Add First Item',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
