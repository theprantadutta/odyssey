import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../providers/statistics_provider.dart';
import '../widgets/stats_card.dart';

class StatisticsDashboardScreen extends ConsumerWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statisticsProvider);

    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      appBar: AppBar(
        backgroundColor: AppColors.cloudGray,
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
              color: AppColors.snowWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: AppSizes.softShadow,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.charcoal,
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
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Your travel journey in numbers',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.slate,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSizes.space16),
            decoration: BoxDecoration(
              color: AppColors.snowWhite,
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
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            )
          : statsState.error != null && statsState.statistics == null
              ? _buildErrorState(context, ref, statsState.error!)
              : statsState.statistics != null
                  ? _buildContent(context, ref, statsState.statistics!)
                  : const SizedBox(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
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
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Please check your connection and try again',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
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

  Widget _buildContent(BuildContext context, WidgetRef ref, stats) {
    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: AppColors.snowWhite,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await ref.read(statisticsProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.space16),
        children: [
          // Overview section
          _buildOverviewSection(context, stats),
          const SizedBox(height: AppSizes.space20),

          // Trips section
          _buildTripsSection(context, stats.trips),
          const SizedBox(height: AppSizes.space16),

          // Activities section
          _buildActivitiesSection(context, stats.activities),
          const SizedBox(height: AppSizes.space16),

          // Memories section
          _buildMemoriesSection(context, stats.memories),
          const SizedBox(height: AppSizes.space16),

          // Budget section
          _buildBudgetSection(context, stats.expenses),
          const SizedBox(height: AppSizes.space16),

          // Packing section
          _buildPackingSection(context, stats.packing),
          const SizedBox(height: AppSizes.space16),

          // Social section
          _buildSocialSection(context, stats.social),
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
                      'Member since ${stats.memberSince}',
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
                  '${stats.totalDaysTraveled}',
                  Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: _buildOverviewStat(
                  context,
                  'Achievement Points',
                  '${stats.achievementPoints}',
                  Icons.stars_rounded,
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

  Widget _buildTripsSection(BuildContext context, trips) {
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
                '${trips.totalTrips}',
                AppColors.oceanTeal,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'This Year',
                '${trips.tripsThisYear}',
                AppColors.mintGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space16),
        Container(
          padding: const EdgeInsets.all(AppSizes.space12),
          decoration: BoxDecoration(
            color: AppColors.warmGray,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Column(
            children: [
              _StatsRow(
                label: 'Planned',
                value: '${trips.plannedTrips}',
                icon: Icons.schedule_rounded,
                color: AppColors.slate,
              ),
              const SizedBox(height: AppSizes.space8),
              _StatsRow(
                label: 'Ongoing',
                value: '${trips.ongoingTrips}',
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.sunnyYellow,
              ),
              const SizedBox(height: AppSizes.space8),
              _StatsRow(
                label: 'Completed',
                value: '${trips.completedTrips}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.mintGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        _StatsRow(
          label: 'Average Trip Duration',
          value: '${trips.averageTripDuration.toStringAsFixed(1)} days',
          icon: Icons.timer_outlined,
          color: AppColors.oceanTeal,
        ),
      ],
    );
  }

  Widget _buildActivitiesSection(BuildContext context, activities) {
    return _StatsSectionCard(
      title: 'Activities',
      subtitle: 'Things you\'ve done',
      icon: Icons.local_activity_rounded,
      color: AppColors.coralBurst,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Total',
                '${activities.totalActivities}',
                AppColors.coralBurst,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'Completed',
                '${activities.completedActivities}',
                AppColors.mintGreen,
              ),
            ),
          ],
        ),
        if (activities.activitiesByCategory.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space16),
          Container(
            padding: const EdgeInsets.all(AppSizes.space12),
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Category',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...activities.activitiesByCategory.entries.map(
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

  Widget _buildMemoriesSection(BuildContext context, memories) {
    return _StatsSectionCard(
      title: 'Memories',
      subtitle: 'Captured moments',
      icon: Icons.photo_camera_rounded,
      color: AppColors.lavenderDream,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Total',
                '${memories.totalMemories}',
                AppColors.lavenderDream,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'This Year',
                '${memories.memoriesThisYear}',
                AppColors.oceanTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetSection(BuildContext context, expenses) {
    return _StatsSectionCard(
      title: 'Budget',
      subtitle: 'Your travel spending',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.mintGreen,
      children: [
        _StatsRow(
          label: 'Total Expenses',
          value: '${expenses.totalExpenses}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.mintGreen,
        ),
        const SizedBox(height: AppSizes.space8),
        _StatsRow(
          label: 'Average Expense',
          value: '\$${expenses.averageExpense.toStringAsFixed(2)}',
          icon: Icons.trending_up_rounded,
          color: AppColors.sunnyYellow,
        ),
        if (expenses.totalAmountByCurrency.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space12),
          Container(
            padding: const EdgeInsets.all(AppSizes.space12),
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'By Currency',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...expenses.totalAmountByCurrency.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _StatsRow(
                      label: entry.key,
                      value: entry.value.toStringAsFixed(2),
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

  Widget _buildPackingSection(BuildContext context, packing) {
    final progress = packing.totalPackingItems > 0
        ? packing.packedItems / packing.totalPackingItems
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
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
                  color: AppColors.lavenderDream.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.luggage_rounded,
                  color: AppColors.lavenderDream,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Packing Progress',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      '${packing.packedItems} of ${packing.totalPackingItems} items packed',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space12,
                  vertical: AppSizes.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lavenderDream.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.lavenderDream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation(AppColors.lavenderDream),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialSection(BuildContext context, social) {
    return _StatsSectionCard(
      title: 'Social',
      subtitle: 'Sharing with others',
      icon: Icons.people_rounded,
      color: AppColors.sunnyYellow,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Trips Shared',
                '${social.tripsShared}',
                AppColors.sunnyYellow,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: _buildMiniStat(
                context,
                'Shared with Me',
                '${social.tripsSharedWithMe}',
                AppColors.oceanTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        Container(
          padding: const EdgeInsets.all(AppSizes.space12),
          decoration: BoxDecoration(
            color: AppColors.warmGray,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Column(
            children: [
              _StatsRow(
                label: 'Templates Created',
                value: '${social.templatesCreated}',
                icon: Icons.bookmarks_outlined,
                color: AppColors.sunnyYellow,
              ),
              const SizedBox(height: AppSizes.space8),
              _StatsRow(
                label: 'Template Uses',
                value: '${social.templatesUsedByOthers}',
                icon: Icons.people_outline_rounded,
                color: AppColors.oceanTeal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, Color color) {
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
              color: AppColors.slate,
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
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
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
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.slate,
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
              color: AppColors.slate,
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
