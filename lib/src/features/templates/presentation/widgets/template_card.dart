import 'package:flutter/material.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';

class TemplateCard extends StatelessWidget {
  final TripTemplateModel template;
  final VoidCallback? onTap;
  final VoidCallback? onUse;
  final VoidCallback? onDelete;
  final bool showActions;

  const TemplateCard({
    super.key,
    required this.template,
    this.onTap,
    this.onUse,
    this.onDelete,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structure = template.structure;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category icon
            Container(
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getCategoryColor(template.category).withValues(alpha: 0.3),
                    _getCategoryColor(template.category).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Text(
                      template.category?.icon ?? '📋',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (template.category != null)
                          Text(
                            template.category!.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (template.isPublic)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space8,
                        vertical: AppSizes.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Public',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (template.description != null) ...[
                    Text(
                      template.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.space12),
                  ],

                  // Template stats
                  Wrap(
                    spacing: AppSizes.space12,
                    runSpacing: AppSizes.space8,
                    children: [
                      if (structure.durationDays != null)
                        _StatChip(
                          icon: Icons.calendar_today_outlined,
                          label: '${structure.durationDays} days',
                        ),
                      if (structure.activities.isNotEmpty)
                        _StatChip(
                          icon: Icons.checklist_outlined,
                          label: '${structure.activities.length} activities',
                        ),
                      if (structure.packingItems.isNotEmpty)
                        _StatChip(
                          icon: Icons.luggage_outlined,
                          label: '${structure.packingItems.length} items',
                        ),
                      _StatChip(
                        icon: Icons.trending_up_outlined,
                        label: '${template.useCount} uses',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (showActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.space16,
                  0,
                  AppSizes.space16,
                  AppSizes.space16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onUse,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Use Template'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.oceanTeal,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: AppSizes.space8),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        tooltip: 'Delete',
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(TemplateCategory? category) {
    switch (category) {
      case TemplateCategory.beach:
        return AppColors.skyBlue;
      case TemplateCategory.adventure:
        return AppColors.coralBurst;
      case TemplateCategory.city:
        return AppColors.lavenderDream;
      case TemplateCategory.cultural:
        return AppColors.goldenGlow;
      case TemplateCategory.roadTrip:
        return AppColors.oceanTeal;
      default:
        return AppColors.oceanTeal;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
