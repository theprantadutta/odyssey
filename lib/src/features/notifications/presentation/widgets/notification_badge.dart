import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_typography.dart';

/// Badge widget to display unread notification count
class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;

  const NotificationBadge({
    super.key,
    required this.count,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final displayCount = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 4 : 0,
        vertical: 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.coralBurst,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: colorScheme.surface,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.coralBurst.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayCount,
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
