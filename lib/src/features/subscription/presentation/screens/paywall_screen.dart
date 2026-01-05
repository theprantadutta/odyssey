import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../providers/purchase_provider.dart';
import '../providers/subscription_provider.dart' show SubscriptionState, subscriptionProvider, isPremiumProvider;

/// Paywall screen shown when users try to access premium features
class PaywallScreen extends ConsumerStatefulWidget {
  final String? featureName;
  final String? customTitle;
  final String? customDescription;
  final IconData? featureIcon;

  const PaywallScreen({
    super.key,
    this.featureName,
    this.customTitle,
    this.customDescription,
    this.featureIcon,
  });

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for purchase success to close the screen
    ref.listenManual(purchaseProvider, (previous, next) {
      if (next.successMessage != null && previous?.successMessage == null) {
        // Purchase successful, show success and close
        _showSuccessAndClose();
      }
    });
  }

  void _showSuccessAndClose() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Welcome to Premium! Enjoy all features.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
    ref.read(purchaseProvider.notifier).clearSuccess();
    Navigator.of(context).pop(true); // Return true to indicate success
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);
    final purchaseState = ref.watch(purchaseProvider);

    // Show error if any
    if (purchaseState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(purchaseState.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: AppColors.pureWhite,
              onPressed: () {
                ref.read(purchaseProvider.notifier).clearError();
              },
            ),
          ),
        );
        ref.read(purchaseProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.snowWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.charcoal),
          onPressed: purchaseState.isPurchasing
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: Column(
                children: [
                  // Feature Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sunnyYellow.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.featureIcon ?? Icons.workspace_premium,
                      color: AppColors.charcoal,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: AppSizes.space24),

                  // Title
                  Text(
                    widget.customTitle ?? 'Unlock ${widget.featureName}',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSizes.space12),

                  // Description
                  Text(
                    widget.customDescription ??
                        '${widget.featureName ?? 'This feature'} is available with Odyssey Premium. Upgrade now to unlock it and many more features!',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.slate,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSizes.space32),

                  // Premium Features List
                  const _PremiumFeaturesList(),

                  const SizedBox(height: AppSizes.space32),

                  // Pricing Options - Use store prices if available, fallback to backend
                  _buildPricingOptions(subscription, purchaseState),

                  const SizedBox(height: AppSizes.space24),

                  // Restore purchases link
                  TextButton(
                    onPressed: purchaseState.isPurchasing
                        ? null
                        : () => ref.read(purchaseProvider.notifier).restorePurchases(),
                    child: Text(
                      'Restore Purchases',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.slate,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSizes.space16),

                  // Terms
                  Text(
                    'Payment will be charged to your account. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mutedGray,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (purchaseState.isPurchasing)
            Container(
              color: AppColors.charcoal.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.space24),
                  decoration: BoxDecoration(
                    color: AppColors.snowWhite,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.sunnyYellow,
                      ),
                      const SizedBox(height: AppSizes.space16),
                      Text(
                        'Processing purchase...',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPricingOptions(SubscriptionState subscription, PurchaseState purchaseState) {
    // Use store prices if available
    final yearlyPrice = purchaseState.yearlyProduct?.price ??
        subscription.pricing?.formattedYearly ??
        '\$24.99/yr';
    final monthlyPrice = purchaseState.monthlyProduct?.price ??
        subscription.pricing?.formattedMonthly ??
        '\$2.99/mo';
    final lifetimePrice = purchaseState.lifetimeProduct?.price ??
        subscription.pricing?.formattedLifetime ??
        '\$49.99';

    final yearlySavings = subscription.pricing?.yearlySavingsPercent ?? 30;

    return Column(
      children: [
        _PricingCard(
          title: 'Yearly',
          price: yearlyPrice,
          subtitle: 'Save $yearlySavings%',
          isRecommended: true,
          isEnabled: !purchaseState.isPurchasing,
          onTap: () => ref.read(purchaseProvider.notifier).purchaseYearly(),
        ),
        const SizedBox(height: AppSizes.space12),
        _PricingCard(
          title: 'Monthly',
          price: monthlyPrice,
          isEnabled: !purchaseState.isPurchasing,
          onTap: () => ref.read(purchaseProvider.notifier).purchaseMonthly(),
        ),
        const SizedBox(height: AppSizes.space12),
        _PricingCard(
          title: 'Lifetime',
          price: lifetimePrice,
          subtitle: 'One-time payment',
          isEnabled: !purchaseState.isPurchasing,
          onTap: () => ref.read(purchaseProvider.notifier).purchaseLifetime(),
        ),
      ],
    );
  }
}

class _PremiumFeaturesList extends StatelessWidget {
  const _PremiumFeaturesList();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.cloudGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium includes:',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: AppSizes.space12),
          const _FeatureItem(icon: Icons.all_inclusive, text: 'Unlimited trips'),
          const _FeatureItem(icon: Icons.cloud, text: '25 GB storage'),
          const _FeatureItem(icon: Icons.videocam, text: 'Video uploads'),
          const _FeatureItem(icon: Icons.map, text: 'World Map view'),
          const _FeatureItem(icon: Icons.calendar_month, text: 'Year in Review'),
          const _FeatureItem(icon: Icons.bar_chart, text: 'Full Statistics'),
          const _FeatureItem(icon: Icons.people, text: 'Edit collaboration'),
          const _FeatureItem(icon: Icons.emoji_events, text: 'All achievements'),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.sunnyYellow,
          ),
          const SizedBox(width: AppSizes.space12),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String? subtitle;
  final bool isRecommended;
  final bool isEnabled;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    this.subtitle,
    this.isRecommended = false,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.space16),
          decoration: BoxDecoration(
            gradient: isRecommended
                ? const LinearGradient(
                    colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isRecommended ? null : AppColors.snowWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: isRecommended
                ? null
                : Border.all(color: AppColors.warmGray, width: 1.5),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: AppSizes.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space8,
                              vertical: AppSizes.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.charcoal,
                              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                            ),
                            child: Text(
                              'Best Value',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isRecommended
                              ? AppColors.charcoal.withValues(alpha: 0.7)
                              : AppColors.slate,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                price,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog version of paywall for in-app prompts
class PaywallDialog extends StatelessWidget {
  final String? featureName;
  final VoidCallback? onUpgrade;

  const PaywallDialog({
    super.key,
    this.featureName,
    this.onUpgrade,
  });

  static Future<void> show(
    BuildContext context, {
    String? featureName,
    VoidCallback? onUpgrade,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PaywallDialog(
        featureName: featureName,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock,
                color: AppColors.charcoal,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSizes.space16),
            Text(
              featureName != null
                  ? '$featureName is Premium'
                  : 'Premium Feature',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Upgrade to Premium to unlock this feature and enjoy unlimited trips, video uploads, and more!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onUpgrade?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnyYellow,
                  foregroundColor: AppColors.charcoal,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.space12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe Later',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.slate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility class for showing paywalls
class PaywallUtils {
  /// Show paywall screen for a feature
  static Future<void> showPaywall(
    BuildContext context, {
    String? featureName,
    String? customTitle,
    String? customDescription,
    IconData? featureIcon,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PaywallScreen(
          featureName: featureName,
          customTitle: customTitle,
          customDescription: customDescription,
          featureIcon: featureIcon,
        ),
      ),
    );
  }

  /// Show quick paywall dialog
  static Future<void> showQuickPaywall(
    BuildContext context, {
    String? featureName,
    VoidCallback? onUpgrade,
  }) {
    return PaywallDialog.show(
      context,
      featureName: featureName,
      onUpgrade: onUpgrade,
    );
  }

  /// Check if feature is available and show paywall if not
  static Future<bool> checkFeatureAccess(
    BuildContext context,
    WidgetRef ref, {
    required String featureName,
    bool showPaywall = true,
  }) async {
    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) return true;

    if (showPaywall) {
      await PaywallUtils.showQuickPaywall(
        context,
        featureName: featureName,
        onUpgrade: () => PaywallUtils.showPaywall(
          context,
          featureName: featureName,
        ),
      );
    }
    return false;
  }
}
