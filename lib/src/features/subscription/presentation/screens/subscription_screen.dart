import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/subscription_model.dart';
import '../providers/subscription_provider.dart';

/// Subscription management screen showing current plan and upgrade options
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: subscription.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(subscriptionProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSizes.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current Plan Card
                    _CurrentPlanCard(
                      status: subscription.status,
                      usage: subscription.usage,
                    ),

                    const SizedBox(height: AppSizes.space24),

                    // Usage Stats
                    if (subscription.usage != null)
                      _UsageSection(usage: subscription.usage!),

                    const SizedBox(height: AppSizes.space24),

                    // Upgrade Section (for free users)
                    if (subscription.status?.isPremium != true)
                      _UpgradeSection(pricing: subscription.pricing),

                    // Features comparison
                    const SizedBox(height: AppSizes.space24),
                    _FeaturesComparison(
                      limits: subscription.limits,
                      isPremium: subscription.isPremium,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionStatus? status;
  final UsageInfo? usage;

  const _CurrentPlanCard({this.status, this.usage});

  @override
  Widget build(BuildContext context) {
    final isPremium = status?.isPremium ?? false;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? AppColors.sunnyYellow : AppColors.charcoal)
                .withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.workspace_premium : Icons.person_outline,
                color: isPremium ? AppColors.charcoal : AppColors.slate,
                size: 28,
              ),
              const SizedBox(width: AppSizes.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? 'Premium' : 'Free Plan',
                    style: AppTypography.headlineSmall.copyWith(
                      color: isPremium ? AppColors.charcoal : AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (status?.plan != null && status!.plan != SubscriptionPlan.free)
                    Text(
                      _getPlanLabel(status!.plan),
                      style: AppTypography.bodySmall.copyWith(
                        color: isPremium ? AppColors.charcoal.withValues(alpha: 0.7) : AppColors.slate,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space12,
                    vertical: AppSizes.space4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    'Active',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (status?.expiresAt != null && status!.plan != SubscriptionPlan.lifetime) ...[
            const SizedBox(height: AppSizes.space12),
            Text(
              'Renews on ${_formatDate(status!.expiresAt!)}',
              style: AppTypography.bodySmall.copyWith(
                color: isPremium ? AppColors.charcoal.withValues(alpha: 0.7) : AppColors.slate,
              ),
            ),
          ],
          if (status?.plan == SubscriptionPlan.lifetime) ...[
            const SizedBox(height: AppSizes.space12),
            Text(
              'Lifetime access - Never expires!',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPlanLabel(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 'Monthly Plan';
      case SubscriptionPlan.yearly:
        return 'Yearly Plan';
      case SubscriptionPlan.lifetime:
        return 'Lifetime Plan';
      case SubscriptionPlan.free:
        return 'Free Plan';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _UsageSection extends StatelessWidget {
  final UsageInfo usage;

  const _UsageSection({required this.usage});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Usage',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            // Storage
            _UsageBar(
              label: 'Storage',
              used: usage.formattedStorageUsed,
              limit: usage.formattedStorageLimit,
              percentage: usage.storageUsedPercentage,
              color: AppColors.oceanTeal,
            ),

            const SizedBox(height: AppSizes.space16),

            // Active Trips
            _UsageBar(
              label: 'Active Trips',
              used: usage.activeTripCount.toString(),
              limit: usage.isUnlimitedTrips ? 'Unlimited' : usage.activeTripLimit.toString(),
              percentage: usage.isUnlimitedTrips
                  ? 0
                  : (usage.activeTripCount / usage.activeTripLimit * 100).clamp(0, 100),
              color: AppColors.coralBurst,
            ),

            const SizedBox(height: AppSizes.space16),

            // Templates
            _UsageBar(
              label: 'Templates',
              used: usage.templateCount.toString(),
              limit: usage.isUnlimitedTemplates ? 'Unlimited' : usage.templateLimit.toString(),
              percentage: usage.isUnlimitedTemplates
                  ? 0
                  : (usage.templateCount / usage.templateLimit * 100).clamp(0, 100),
              color: AppColors.lavenderDream,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final String used;
  final String limit;
  final double percentage;
  final Color color;

  const _UsageBar({
    required this.label,
    required this.used,
    required this.limit,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = percentage >= 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            Text(
              '$used / $limit',
              style: AppTypography.bodySmall.copyWith(
                color: isWarning ? AppColors.error : AppColors.slate,
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
            valueColor: AlwaysStoppedAnimation(
              isWarning ? AppColors.error : color,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _UpgradeSection extends StatelessWidget {
  final PricingInfo? pricing;

  const _UpgradeSection({this.pricing});

  @override
  Widget build(BuildContext context) {
    if (pricing == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upgrade to Premium',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Text(
          'Unlock unlimited trips, video uploads, and more!',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: AppSizes.space16),

        // Pricing options
        _PricingOption(
          title: 'Monthly',
          price: pricing!.formattedMonthly,
          isPopular: false,
          onTap: () {
            // TODO: Open payment sheet
          },
        ),

        const SizedBox(height: AppSizes.space12),

        _PricingOption(
          title: 'Yearly',
          price: pricing!.formattedYearly,
          subtitle: 'Save ${pricing!.yearlySavingsPercent}% (${pricing!.formattedYearlyMonthly})',
          isPopular: true,
          onTap: () {
            // TODO: Open payment sheet
          },
        ),

        const SizedBox(height: AppSizes.space12),

        _PricingOption(
          title: 'Lifetime',
          price: pricing!.formattedLifetime,
          subtitle: 'One-time payment, forever access',
          isPopular: false,
          onTap: () {
            // TODO: Open payment sheet
          },
        ),
      ],
    );
  }
}

class _PricingOption extends StatelessWidget {
  final String title;
  final String price;
  final String? subtitle;
  final bool isPopular;
  final VoidCallback onTap;

  const _PricingOption({
    required this.title,
    required this.price,
    this.subtitle,
    required this.isPopular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: isPopular ? AppColors.sunnyYellow.withValues(alpha: 0.1) : AppColors.snowWhite,
          border: Border.all(
            color: isPopular ? AppColors.sunnyYellow : AppColors.warmGray,
            width: isPopular ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: AppSizes.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.space8,
                            vertical: AppSizes.space4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sunnyYellow,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: Text(
                            'Best Value',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.charcoal,
                              fontWeight: FontWeight.w600,
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
                        color: AppColors.slate,
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
    );
  }
}

class _FeaturesComparison extends StatelessWidget {
  final SubscriptionLimits? limits;
  final bool isPremium;

  const _FeaturesComparison({this.limits, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Features Comparison',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            _FeatureRow(
              feature: 'Active Trips',
              free: '5',
              premium: 'Unlimited',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'Storage',
              free: '1 GB',
              premium: '25 GB',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'Video Uploads',
              free: 'No',
              premium: 'Yes',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'World Map',
              free: 'No',
              premium: 'Yes',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'Year in Review',
              free: 'No',
              premium: 'Yes',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'Full Statistics',
              free: 'No',
              premium: 'Yes',
              hasFeature: isPremium,
            ),
            _FeatureRow(
              feature: 'Edit Collaboration',
              free: 'No',
              premium: 'Yes',
              hasFeature: isPremium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String feature;
  final String free;
  final String premium;
  final bool hasFeature;

  const _FeatureRow({
    required this.feature,
    required this.free,
    required this.premium,
    required this.hasFeature,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: AppTypography.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              free,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (premium == 'Yes')
                  Icon(
                    Icons.check_circle,
                    color: hasFeature ? AppColors.success : AppColors.sunnyYellow,
                    size: 20,
                  )
                else
                  Text(
                    premium,
                    style: AppTypography.bodySmall.copyWith(
                      color: hasFeature ? AppColors.success : AppColors.sunnyYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
