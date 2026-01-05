import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';

/// Banner prompting users to upgrade to premium
class UpgradeBanner extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;
  final bool showDismiss;
  final UpgradeBannerStyle style;

  const UpgradeBanner({
    super.key,
    this.title,
    this.subtitle,
    this.onUpgrade,
    this.onDismiss,
    this.showDismiss = false,
    this.style = UpgradeBannerStyle.standard,
  });

  /// Factory for limit reached banner
  factory UpgradeBanner.limitReached({
    required String limitName,
    required int currentCount,
    required int maxCount,
    VoidCallback? onUpgrade,
  }) {
    return UpgradeBanner(
      title: '$limitName limit reached',
      subtitle: 'You\'ve used $currentCount of $maxCount. Upgrade to Premium for unlimited access.',
      onUpgrade: onUpgrade,
      style: UpgradeBannerStyle.warning,
    );
  }

  /// Factory for storage warning banner
  factory UpgradeBanner.storageWarning({
    required double usagePercent,
    VoidCallback? onUpgrade,
  }) {
    return UpgradeBanner(
      title: 'Storage ${usagePercent.toStringAsFixed(0)}% full',
      subtitle: 'Running low on space. Upgrade to Premium for 25GB storage.',
      onUpgrade: onUpgrade,
      style: UpgradeBannerStyle.warning,
    );
  }

  /// Factory for feature locked banner
  factory UpgradeBanner.featureLocked({
    required String featureName,
    VoidCallback? onUpgrade,
  }) {
    return UpgradeBanner(
      title: '$featureName is a Premium feature',
      subtitle: 'Unlock $featureName and more with Premium.',
      onUpgrade: onUpgrade,
      style: UpgradeBannerStyle.locked,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Upgrade to Premium',
                  style: AppTypography.titleSmall.copyWith(
                    color: _getTextColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: _getTextColor().withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space8),
          Column(
            children: [
              if (showDismiss && onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: _getTextColor().withValues(alpha: 0.6),
                    size: 20,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              TextButton(
                onPressed: onUpgrade,
                style: TextButton.styleFrom(
                  backgroundColor: _getButtonColor(),
                  foregroundColor: _getButtonTextColor(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space12,
                    vertical: AppSizes.space8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    switch (style) {
      case UpgradeBannerStyle.standard:
        iconData = Icons.workspace_premium;
        break;
      case UpgradeBannerStyle.warning:
        iconData = Icons.warning_amber_rounded;
        break;
      case UpgradeBannerStyle.locked:
        iconData = Icons.lock;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.space8),
      decoration: BoxDecoration(
        color: _getIconBackgroundColor(),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: _getIconColor(),
        size: 24,
      ),
    );
  }

  LinearGradient _getGradient() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return const LinearGradient(
          colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case UpgradeBannerStyle.warning:
        return LinearGradient(
          colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.warning.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case UpgradeBannerStyle.locked:
        return const LinearGradient(
          colors: [Color(0xFFE8E8E8), Color(0xFFF5F5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getShadowColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.sunnyYellow.withValues(alpha: 0.3);
      case UpgradeBannerStyle.warning:
        return AppColors.warning.withValues(alpha: 0.2);
      case UpgradeBannerStyle.locked:
        return AppColors.charcoal.withValues(alpha: 0.1);
    }
  }

  Color _getTextColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.charcoal;
      case UpgradeBannerStyle.warning:
        return AppColors.charcoal;
      case UpgradeBannerStyle.locked:
        return AppColors.charcoal;
    }
  }

  Color _getIconBackgroundColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.charcoal.withValues(alpha: 0.1);
      case UpgradeBannerStyle.warning:
        return AppColors.warning.withValues(alpha: 0.2);
      case UpgradeBannerStyle.locked:
        return AppColors.slate.withValues(alpha: 0.2);
    }
  }

  Color _getIconColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.charcoal;
      case UpgradeBannerStyle.warning:
        return AppColors.warning;
      case UpgradeBannerStyle.locked:
        return AppColors.slate;
    }
  }

  Color _getButtonColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.charcoal;
      case UpgradeBannerStyle.warning:
        return AppColors.warning;
      case UpgradeBannerStyle.locked:
        return AppColors.sunnyYellow;
    }
  }

  Color _getButtonTextColor() {
    switch (style) {
      case UpgradeBannerStyle.standard:
        return AppColors.pureWhite;
      case UpgradeBannerStyle.warning:
        return AppColors.pureWhite;
      case UpgradeBannerStyle.locked:
        return AppColors.charcoal;
    }
  }
}

enum UpgradeBannerStyle {
  standard,
  warning,
  locked,
}

/// Compact inline upgrade prompt
class UpgradeInlinePrompt extends StatelessWidget {
  final String message;
  final VoidCallback? onUpgrade;

  const UpgradeInlinePrompt({
    super.key,
    required this.message,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: AppColors.sunnyYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: AppColors.sunnyYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium,
            color: AppColors.sunnyYellow,
            size: 18,
          ),
          const SizedBox(width: AppSizes.space8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.charcoal,
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
              'Upgrade',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.sunnyYellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
