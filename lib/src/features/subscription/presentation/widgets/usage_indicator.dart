import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';

/// Compact usage indicator widget
class UsageIndicator extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final bool isUnlimited;
  final Color? color;
  final bool showBar;

  const UsageIndicator({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.isUnlimited = false,
    this.color,
    this.showBar = true,
  });

  double get percentage => isUnlimited ? 0 : (used / limit * 100).clamp(0, 100);
  bool get isWarning => percentage >= 80;
  bool get isAtLimit => !isUnlimited && used >= limit;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? (isWarning ? AppColors.error : AppColors.oceanTeal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.slate,
              ),
            ),
            Row(
              children: [
                Text(
                  isUnlimited ? '$used' : '$used / $limit',
                  style: AppTypography.bodySmall.copyWith(
                    color: isAtLimit ? AppColors.error : AppColors.charcoal,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isUnlimited) ...[
                  const SizedBox(width: AppSizes.space4),
                  Icon(
                    Icons.all_inclusive,
                    size: 14,
                    color: AppColors.sunnyYellow,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (showBar && !isUnlimited) ...[
          const SizedBox(height: AppSizes.space4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.warmGray,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Storage usage indicator with formatted sizes
class StorageUsageIndicator extends StatelessWidget {
  final int usedBytes;
  final int limitBytes;
  final bool showUpgrade;
  final VoidCallback? onUpgrade;

  const StorageUsageIndicator({
    super.key,
    required this.usedBytes,
    required this.limitBytes,
    this.showUpgrade = true,
    this.onUpgrade,
  });

  double get percentage => (usedBytes / limitBytes * 100).clamp(0, 100);
  bool get isWarning => percentage >= 80;
  bool get isCritical => percentage >= 95;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final barColor = isCritical
        ? AppColors.error
        : isWarning
            ? AppColors.warning
            : AppColors.oceanTeal;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: isWarning
            ? barColor.withValues(alpha: 0.1)
            : AppColors.cloudGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: isWarning
            ? Border.all(color: barColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning ? Icons.storage : Icons.cloud_done,
                size: 18,
                color: barColor,
              ),
              const SizedBox(width: AppSizes.space8),
              Text(
                'Storage',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatBytes(usedBytes)} / ${_formatBytes(limitBytes)}',
                style: AppTypography.bodySmall.copyWith(
                  color: isWarning ? barColor : AppColors.slate,
                  fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.warmGray,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
          if (isWarning && showUpgrade) ...[
            const SizedBox(height: AppSizes.space8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: barColor,
                ),
                const SizedBox(width: AppSizes.space4),
                Expanded(
                  child: Text(
                    isCritical
                        ? 'Storage almost full!'
                        : 'Running low on storage',
                    style: AppTypography.bodySmall.copyWith(
                      color: barColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onUpgrade,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space8,
                      vertical: AppSizes.space4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Get more',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.sunnyYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular usage indicator
class CircularUsageIndicator extends StatelessWidget {
  final double percentage;
  final String label;
  final String value;
  final Color? color;
  final double size;
  final double strokeWidth;

  const CircularUsageIndicator({
    super.key,
    required this.percentage,
    required this.label,
    required this.value,
    this.color,
    this.size = 80,
    this.strokeWidth = 8,
  });

  bool get isWarning => percentage >= 80;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? (isWarning ? AppColors.error : AppColors.oceanTeal);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.warmGray,
              valueColor: AlwaysStoppedAnimation(indicatorColor),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: indicatorColor,
                ),
              ),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Usage limit badge for cards
class UsageLimitBadge extends StatelessWidget {
  final int used;
  final int limit;
  final bool isUnlimited;

  const UsageLimitBadge({
    super.key,
    required this.used,
    required this.limit,
    this.isUnlimited = false,
  });

  bool get isAtLimit => !isUnlimited && used >= limit;
  bool get isNearLimit => !isUnlimited && used >= limit * 0.8;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isAtLimit
        ? AppColors.error.withValues(alpha: 0.1)
        : isNearLimit
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.cloudGray;

    final textColor = isAtLimit
        ? AppColors.error
        : isNearLimit
            ? AppColors.warning
            : AppColors.slate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnlimited)
            Icon(
              Icons.all_inclusive,
              size: 12,
              color: AppColors.sunnyYellow,
            )
          else
            Text(
              '$used/$limit',
              style: AppTypography.labelSmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
