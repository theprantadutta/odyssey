import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../ads/presentation/widgets/watch_ad_to_unlock_button.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/widgets/temporary_unlock_banner.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../providers/statistics_provider.dart';
import '../../data/models/statistics_model.dart';

class YearInReviewScreen extends ConsumerWidget {
  const YearInReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess =
        ref.watch(featureAccessProvider(PremiumFeature.yearInReview));

    // Show paywall for users without access (free + no active rewarded unlock).
    if (!hasAccess) {
      return _buildPaywallScreen(context, ref);
    }

    final reviewState = ref.watch(yearInReviewProvider);
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Year in Review'),
        actions: [
          // Year selector
          PopupMenuButton<int>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${reviewState.selectedYear}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            onSelected: (year) {
              ref.read(yearInReviewProvider.notifier).changeYear(year);
            },
            itemBuilder: (context) => List.generate(
              5,
              (index) => PopupMenuItem(
                value: currentYear - index,
                child: Text('${currentYear - index}'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          const TemporaryUnlockBanner(feature: PremiumFeature.yearInReview),
      body: reviewState.isLoading && reviewState.stats == null
          ? const Center(child: CircularProgressIndicator())
          : reviewState.error != null && reviewState.stats == null
              ? _buildErrorState(context, ref, reviewState.error!)
              : reviewState.stats != null
                  ? _buildContent(context, reviewState.stats!)
                  : const SizedBox(),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: AppSizes.space16),
          const Text('Failed to load year in review'),
          const SizedBox(height: AppSizes.space8),
          ElevatedButton(
            onPressed: () => ref.read(yearInReviewProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, YearInReviewStats stats) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.space16),
      children: [
        // Header
        _buildHeader(context, stats),
        const SizedBox(height: AppSizes.space24),

        // Main stats grid
        _buildMainStatsGrid(context, stats),
        const SizedBox(height: AppSizes.space24),

        // Highlights
        if (stats.mostActiveMonth != null ||
            stats.mostUsedExpenseCategory != null)
          _buildHighlights(context, stats),

        // Destinations
        if (stats.topDestinations.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space24),
          _buildDestinations(context, stats),
        ],

        // Trips by month
        if (stats.tripsByMonth.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space24),
          _buildTripsByMonth(context, stats),
        ],

        // Expenses
        if (stats.totalExpensesByCurrency.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space24),
          _buildExpenses(context, stats),
        ],

        // Achievements are not part of the year-in-review payload, so there is
        // nothing here to show. The section was reading fields no endpoint
        // sends.

        const SizedBox(height: AppSizes.space32),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, YearInReviewStats stats) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.oceanTeal,
            AppColors.mintGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            '${stats.year}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            'Your Year in Travel',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: AppSizes.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeaderStat(context, '${stats.totalTrips}', 'Trips'),
              _buildHeaderStat(context, '${stats.totalDaysTraveled}', 'Days'),
              // Destinations are not recorded yet, so a "Cities" tile could
              // only ever read zero - which looks like a measurement rather
              // than an absence. Shown only once there is something to count.
              if (stats.destinationDataAvailable)
                _buildHeaderStat(
                    context, '${stats.topDestinations.length}', 'Places')
              else
                _buildHeaderStat(
                    context, '${stats.totalActivities}', 'Activities'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
        ),
      ],
    );
  }

  Widget _buildMainStatsGrid(BuildContext context, YearInReviewStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSizes.space12,
      crossAxisSpacing: AppSizes.space12,
      childAspectRatio: 1.5,
      children: [
        _buildStatTile(
          context,
          '${stats.totalActivities}',
          'Activities',
          Icons.local_activity,
          AppColors.coralBurst,
        ),
        _buildStatTile(
          context,
          '${stats.totalMemories}',
          'Memories',
          Icons.photo_camera,
          AppColors.lavenderDream,
        ),
        // Achievement figures are not part of this payload. These two tiles
        // read fields no endpoint sends, so they rendered zeros that looked
        // like measurements. Replaced with spending, which the server does
        // report - named in its own currency rather than a bare number.
        _buildStatTile(
          context,
          '${stats.totalSpent.toStringAsFixed(0)} ${stats.reportingCurrency}',
          'Spent',
          Icons.payments_outlined,
          AppColors.sunnyYellow,
        ),
        _buildStatTile(
          context,
          '${stats.totalActivities}',
          'Activities',
          Icons.hiking,
          AppColors.mintGreen,
        ),
      ],
    );
  }

  Widget _buildStatTile(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSizes.space8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
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

  Widget _buildHighlights(BuildContext context, YearInReviewStats stats) {
    // The longest trip is not part of the payload; it was read from a field no
    // endpoint sends. What is here is what the server actually reports.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highlights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSizes.space12),
            if (stats.mostActiveMonth != null)
              _buildHighlightRow(
                context,
                Icons.calendar_month,
                'Busiest month',
                stats.mostActiveMonth!,
              ),
            if (stats.mostUsedExpenseCategory != null)
              _buildHighlightRow(
                context,
                Icons.category_outlined,
                'Most spent on',
                stats.mostUsedExpenseCategory!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSizes.space12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }


  Widget _buildDestinations(BuildContext context, YearInReviewStats stats) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place, color: AppColors.coralBurst),
                const SizedBox(width: AppSizes.space8),
                Text(
                  'Top Destinations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),
            Wrap(
              spacing: AppSizes.space8,
              runSpacing: AppSizes.space8,
              children: stats.topDestinations.map((dest) {
                return Chip(
                  label: Text(dest),
                  backgroundColor: AppColors.oceanTeal.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppColors.oceanTeal.withValues(alpha: 0.3)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsByMonth(BuildContext context, YearInReviewStats stats) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: AppColors.oceanTeal),
                const SizedBox(width: AppSizes.space8),
                Text(
                  'Trips by Month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),
            ...stats.tripsByMonth.entries.map((entry) {
              final maxTrips = stats.tripsByMonth.values.reduce(
                (a, b) => a > b ? a : b,
              );
              final barWidth = maxTrips > 0 ? entry.value / maxTrips : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key.substring(0, 3),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.oceanTeal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.space8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${entry.value}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenses(BuildContext context, YearInReviewStats stats) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppColors.mintGreen),
                const SizedBox(width: AppSizes.space8),
                Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),
            ...stats.totalExpensesByCurrency.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      entry.value.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.mintGreen,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }


  Widget _buildPaywallScreen(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Year in Review'),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSizes.space24),
          padding: const EdgeInsets.all(AppSizes.space24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: colorScheme.onSurface,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              Text(
                'Year in Review',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                'Relive your travel memories with a beautiful yearly summary. See your trips, destinations, and achievements at a glance!',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.space24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => PaywallUtils.showPaywall(
                    context,
                    featureName: 'Year in Review',
                    featureIcon: Icons.calendar_month,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sunnyYellow,
                    foregroundColor: colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space16,
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
              // Free users can watch a rewarded ad for 24h access, then reload.
              const SizedBox(height: AppSizes.space12),
              WatchAdToUnlockButton(
                feature: PremiumFeature.yearInReview,
                onUnlocked: () =>
                    ref.read(yearInReviewProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
