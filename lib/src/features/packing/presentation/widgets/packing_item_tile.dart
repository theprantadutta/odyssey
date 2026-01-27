import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/packing_model.dart';

/// A tile widget representing a packing item with checkbox
class PackingItemTile extends StatelessWidget {
  final PackingItemModel item;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PackingItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.space40),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        if (onDelete != null) {
          HapticFeedback.mediumImpact();
          onDelete!();
        }
        return false; // We handle deletion manually
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onTap != null) {
            onTap!();
          } else {
            onToggle();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
          decoration: BoxDecoration(
            color: item.isPacked
                ? AppColors.mintGreen.withValues(alpha: 0.1)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: item.isPacked
                  ? AppColors.mintGreen.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerHighest,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggle();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.isPacked
                        ? AppColors.mintGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(
                      color: item.isPacked
                          ? AppColors.mintGreen
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: item.isPacked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),

              const SizedBox(width: AppSizes.space12),

              // Item content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: item.isPacked
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              decoration: item.isPacked
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: AppSizes.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space8,
                              vertical: AppSizes.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                            ),
                            child: Text(
                              'x${item.quantity}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.skyBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        item.notes!,
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Category icon
              const SizedBox(width: AppSizes.space8),
              Text(
                PackingCategory.fromString(item.category).icon,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
