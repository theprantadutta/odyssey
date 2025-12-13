import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/packing_model.dart';

/// Progress indicator for packing list
class PackingProgressIndicator extends StatelessWidget {
  final int total;
  final int packed;
  final PackingProgressResponse? progress;

  const PackingProgressIndicator({
    super.key,
    required this.total,
    required this.packed,
    this.progress,
  });

  double get progressPercent => total > 0 ? (packed / total) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.oceanTeal,
            AppColors.oceanTeal.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.oceanTeal.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Packing Progress',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    '$packed of $total items packed',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),

              // Circular progress
              _buildCircularProgress(),
            ],
          ),

          const SizedBox(height: AppSizes.space20),

          // Linear progress bar
          _buildLinearProgress(),

          // Category breakdown
          if (progress != null && progress!.byCategory.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space20),
            _buildCategoryBreakdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularProgress() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: progressPercent,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Percentage text
          Text(
            '${(progressPercent * 100).toInt()}%',
            style: AppTypography.titleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinearProgress() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          child: LinearProgressIndicator(
            value: progressPercent,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By Category',
          style: AppTypography.labelMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          children: progress!.byCategory.map((cat) {
            final category = PackingCategory.fromString(cat.category);
            final isComplete = cat.packed == cat.total && cat.total > 0;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                border: Border.all(
                  color: isComplete
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.icon,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Text(
                    '${cat.packed}/${cat.total}',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: AppSizes.space4),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Compact progress indicator for headers
class PackingProgressCompact extends StatelessWidget {
  final int total;
  final int packed;

  const PackingProgressCompact({
    super.key,
    required this.total,
    required this.packed,
  });

  double get progressPercent => total > 0 ? (packed / total) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: progressPercent == 1.0
            ? AppColors.mintGreen.withValues(alpha: 0.15)
            : AppColors.skyBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progressPercent == 1.0)
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: AppColors.mintGreen,
            )
          else
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progressPercent,
                strokeWidth: 2,
                backgroundColor: AppColors.skyBlue.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.skyBlue),
              ),
            ),
          const SizedBox(width: AppSizes.space8),
          Text(
            '$packed/$total',
            style: AppTypography.labelSmall.copyWith(
              color: progressPercent == 1.0
                  ? AppColors.mintGreen
                  : AppColors.skyBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
