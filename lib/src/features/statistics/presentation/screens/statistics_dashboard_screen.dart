import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../../subscription/presentation/widgets/upgrade_banner.dart';
import '../providers/statistics_provider.dart';
class StatisticsDashboardScreen extends ConsumerWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statisticsProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: AppSizes.space16,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: AppSizes.softShadow,
            ),
            child: Icon(
              Icons.arrow_back,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Your travel journey in numbers',
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSizes.space16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: AppSizes.softShadow,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.oceanTeal,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                if (!isPremium) {
                  PaywallUtils.showPaywall(
                    context,
                    featureName: 'Year in Review',
                    featureIcon: Icons.calendar_month,
                  );
                  return;
                }
                context.push('${AppRoutes.statistics}/year-review');
              },
              tooltip: 'Year in Review',
            ),
          ),
        ],
      ),
      body: statsState.isLoading && statsState.statistics == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.lemonLight,
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppColors.sunnyYellow,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  Text(
                    'Loading your statistics...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : statsState.error != null && statsState.statistics == null
              ? _buildErrorState(context, ref, statsState.error!)
              : statsState.statistics != null
                  ? _buildContent(context, ref, statsState.statistics!, isPremium)
                  : const SizedBox(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load statistics',
              style: AppTypography.titleMedium.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Please check your connection and try again',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(statisticsProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunnyYellow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                  vertical: AppSizes.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, stats, bool isPremium) {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: colorScheme.surface,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await ref.read(statisticsProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.space16),
        children: [
          // Upgrade banner for free users
          if (!isPremium)
            UpgradeBanner(
              title: 'Unlock Full Statistics',
              subtitle: 'Get detailed insights, Year in Review, and more with Premium!',
              onUpgrade: () => PaywallUtils.showPaywall(
                context,
                featureName: 'Full Statistics',
                featureIcon: Icons.bar_chart,
              ),
            ),

          // Overview section
          _buildOverviewSection(context, stats),
          const SizedBox(height: AppSizes.space20),

          // Trips section
          _buildTripsSection(context, stats),
          const SizedBox(height: AppSizes.space16),

          // Activities section
          _buildActivitiesSection(context, stats),
          const SizedBox(height: AppSizes.space16),

          // Memories section
          _buildMemoriesSection(context, stats),
          const SizedBox(height: AppSizes.space16),

          // Budget section
          _buildBudgetSection(context, stats),
          const SizedBox(height: AppSizes.space16),

          // Destinations section
          _buildDestinationsSection(context, stats),
          const SizedBox(height: AppSizes.space24),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context, stats) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.sunnyYellow,
            AppColors.sunnyYellow.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.sunnyYellow.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Travel Journey',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${stats.totalTrips} trips, ${stats.countriesVisited} destinations',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space20),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  context,
                  'Days Traveled',
                  '${stats.totalDaysOfTravel}',
                  Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: _buildOverviewStat(
                  context,
                  'Activities',
                  '${stats.totalActivities}',
                  Icons.local_activity_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: AppSizes.space8),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripsSection(BuildContext context, stats) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatsSectionCard(
      title: 'Trips',
      subtitle: 'Your travel adventures',
      icon: Icons.flight_takeoff_rounded,
      color: AppColors.oceanTeal,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Total',
                '${stats.totalTrips}',
                AppColors.oceanTeal,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'Completed',
                '${stats.completedTrips}',
                AppColors.mintGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space16),
        Container(
          padding: const EdgeInsets.all(AppSizes.space12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Column(
            children: [
              _StatsRow(
                label: 'Planned',
                value: '${stats.plannedTrips}',
                icon: Icons.schedule_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSizes.space8),
              _StatsRow(
                label: 'Ongoing',
                value: '${stats.ongoingTrips}',
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.sunnyYellow,
              ),
              const SizedBox(height: AppSizes.space8),
              _StatsRow(
                label: 'Completed',
                value: '${stats.completedTrips}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.mintGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesSection(BuildContext context, stats) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatsSectionCard(
      title: 'Activities',
      subtitle: 'Things you\'ve done',
      icon: Icons.local_activity_rounded,
      color: AppColors.coralBurst,
      children: [
        _buildMiniStat(
          context,
          'Total Activities',
          '${stats.totalActivities}',
          AppColors.coralBurst,
        ),
        if (stats.activitiesByCategory.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space16),
          Container(
            padding: const EdgeInsets.all(AppSizes.space12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Category',
                  style: AppTypography.labelSmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...stats.activitiesByCategory.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _StatsRow(
                      label: _formatCategoryName(entry.key),
                      value: '${entry.value}',
                      color: AppColors.coralBurst,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemoriesSection(BuildContext context, stats) {
    return _StatsSectionCard(
      title: 'Memories',
      subtitle: 'Captured moments',
      icon: Icons.photo_camera_rounded,
      color: AppColors.lavenderDream,
      children: [
        _buildMiniStat(
          context,
          'Total Photos',
          '${stats.totalMemories}',
          AppColors.lavenderDream,
        ),
      ],
    );
  }

  Widget _buildBudgetSection(BuildContext context, stats) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatsSectionCard(
      title: 'Budget',
      subtitle: 'Your travel spending',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.mintGreen,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Total Expenses',
                '${stats.totalExpenses}',
                AppColors.mintGreen,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'Total Amount',
                '\$${stats.totalExpenseAmount.toStringAsFixed(0)}',
                AppColors.sunnyYellow,
              ),
            ),
          ],
        ),
        if (stats.expensesByCategory.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space12),
          Container(
            padding: const EdgeInsets.all(AppSizes.space12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Category',
                  style: AppTypography.labelSmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...stats.expensesByCategory.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _StatsRow(
                      label: _formatCategoryName(entry.key),
                      value: '\$${entry.value.toStringAsFixed(0)}',
                      color: AppColors.mintGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDestinationsSection(BuildContext context, stats) {
    if (stats.uniqueDestinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return _StatsSectionCard(
      title: 'Destinations',
      subtitle: 'Places you\'ve explored',
      icon: Icons.place_rounded,
      color: AppColors.oceanTeal,
      children: [
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          children: stats.uniqueDestinations.take(10).map<Widget>((destination) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space4,
              ),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                border: Border.all(
                  color: AppColors.oceanTeal.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _formatCategoryName(destination),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.oceanTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _StatsSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _StatsSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          ...children,
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  const _StatsRow({
    required this.label,
    required this.value,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSizes.space8),
        ],
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
