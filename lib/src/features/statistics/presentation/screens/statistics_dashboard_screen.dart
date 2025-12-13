import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../providers/statistics_provider.dart';
import '../widgets/stats_card.dart';

class StatisticsDashboardScreen extends ConsumerWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {
              context.push('${AppRoutes.statistics}/year-review');
            },
            tooltip: 'Year in Review',
          ),
        ],
      ),
      body: statsState.isLoading && statsState.statistics == null
          ? const Center(child: CircularProgressIndicator())
          : statsState.error != null && statsState.statistics == null
              ? _buildErrorState(context, ref, statsState.error!)
              : statsState.statistics != null
                  ? _buildContent(context, statsState.statistics!)
                  : const SizedBox(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSizes.space16),
            const Text('Failed to load statistics'),
            const SizedBox(height: AppSizes.space8),
            ElevatedButton(
              onPressed: () => ref.read(statisticsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, stats) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.space16),
        children: [
          // Overview section
          _buildOverviewSection(context, stats),
          const SizedBox(height: AppSizes.space24),

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
          ProgressStatCard(
            title: 'Packing Progress',
            current: stats.packing.packedItems,
            total: stats.packing.totalPackingItems,
            icon: Icons.luggage,
            color: AppColors.lavenderDream,
          ),
          const SizedBox(height: AppSizes.space16),

          // Social section
          _buildSocialSection(context, stats.social),
          const SizedBox(height: AppSizes.space24),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context, stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Travel Journey',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSizes.space4),
        Text(
          'Member since ${stats.memberSince}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: AppSizes.space16),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Days Traveled',
                value: '${stats.totalDaysTraveled}',
                icon: Icons.calendar_today,
                color: AppColors.oceanTeal,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: StatsCard(
                title: 'Achievement Points',
                value: '${stats.achievementPoints}',
                icon: Icons.stars,
                color: AppColors.sunnyYellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripsSection(BuildContext context, trips) {
    return StatsSectionCard(
      title: 'Trips',
      icon: Icons.flight_takeoff,
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
        const SizedBox(height: AppSizes.space12),
        const Divider(),
        StatsRow(
          label: 'Planned',
          value: '${trips.plannedTrips}',
          icon: Icons.schedule,
        ),
        StatsRow(
          label: 'Ongoing',
          value: '${trips.ongoingTrips}',
          icon: Icons.play_circle_outline,
          valueColor: AppColors.sunnyYellow,
        ),
        StatsRow(
          label: 'Completed',
          value: '${trips.completedTrips}',
          icon: Icons.check_circle_outline,
          valueColor: AppColors.mintGreen,
        ),
        const Divider(),
        StatsRow(
          label: 'Average Trip Duration',
          value: '${trips.averageTripDuration.toStringAsFixed(1)} days',
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }

  Widget _buildActivitiesSection(BuildContext context, activities) {
    return StatsSectionCard(
      title: 'Activities',
      icon: Icons.local_activity,
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
          const SizedBox(height: AppSizes.space12),
          const Divider(),
          Text(
            'By Category',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSizes.space8),
          ...activities.activitiesByCategory.entries.map(
            (entry) => StatsRow(
              label: _formatCategoryName(entry.key),
              value: '${entry.value}',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemoriesSection(BuildContext context, memories) {
    return StatsSectionCard(
      title: 'Memories',
      icon: Icons.photo_camera,
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
    return StatsSectionCard(
      title: 'Budget',
      icon: Icons.account_balance_wallet,
      color: AppColors.mintGreen,
      children: [
        StatsRow(
          label: 'Total Expenses',
          value: '${expenses.totalExpenses}',
          icon: Icons.receipt_long,
        ),
        StatsRow(
          label: 'Average Expense',
          value: '\$${expenses.averageExpense.toStringAsFixed(2)}',
          icon: Icons.trending_up,
        ),
        if (expenses.totalAmountByCurrency.isNotEmpty) ...[
          const Divider(),
          Text(
            'By Currency',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSizes.space8),
          ...expenses.totalAmountByCurrency.entries.map(
            (entry) => StatsRow(
              label: entry.key,
              value: entry.value.toStringAsFixed(2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialSection(BuildContext context, social) {
    return StatsSectionCard(
      title: 'Social',
      icon: Icons.people,
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
        StatsRow(
          label: 'Templates Created',
          value: '${social.templatesCreated}',
          icon: Icons.bookmarks_outlined,
        ),
        StatsRow(
          label: 'Template Uses',
          value: '${social.templatesUsedByOthers}',
          icon: Icons.people_outline,
        ),
      ],
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
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
