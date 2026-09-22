import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../../subscription/presentation/widgets/temporary_unlock_banner.dart';
import '../../data/models/statistics_model.dart';
import '../providers/statistics_provider.dart';

/// A year, summarised.
class YearInReviewScreen extends ConsumerWidget {
  const YearInReviewScreen({super.key});

  static String _symbolFor(String code) {
    for (final currency in commonCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(
      featureAccessProvider(PremiumFeature.yearInReview),
    );
    if (!hasAccess) return _buildPaywall(context);

    final t = context.odyssey;
    final state = ref.watch(yearInReviewProvider);
    final currentYear = DateTime.now().year;

    return OdysseyScaffold(
      // A temporary unlock looks exactly like Pro until the day it stops
      // working. Saying how long is left turns "it broke" into "it ran out".
      bottomBar: const TemporaryUnlockBanner(
        feature: PremiumFeature.yearInReview,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.contentTop,
          AppSizes.screenPadding,
          AppSizes.scrollBottom,
        ),
        children: [
          ScreenHeader(
            onBack: () => context.pop(),
            trailing: CircleButton(
              icon: Icons.expand_more_rounded,
              onPressed: () async {
                final picked = await showOdysseyPicker<int>(
                  context: context,
                  title: 'Year',
                  options: List.generate(5, (i) => currentYear - i),
                  labelOf: (year) => '$year',
                  selected: state.selectedYear,
                );
                if (picked != null) {
                  ref.read(yearInReviewProvider.notifier).changeYear(picked);
                }
              },
              semanticLabel: 'Choose a year',
            ),
          ),
          const SizedBox(height: AppSizes.space20),
          Text(
            '${state.selectedYear}\nin review',
            style: AppTypography.screenTitle.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSizes.space20),

          if (state.isLoading && state.stats == null)
            const Column(
              children: [
                Skeleton(
                  width: double.infinity,
                  height: 190,
                  radius: AppSizes.radiusHero,
                ),
                SizedBox(height: AppSizes.space12),
                Skeleton.row(),
              ],
            )
          else if (state.error != null && state.stats == null)
            OdysseyErrorState.fromError(
              state.error,
              message: 'Your year in review could not be loaded.',
              onRetry: () => ref.read(yearInReviewProvider.notifier).refresh(),
            )
          else if (state.stats != null)
            ..._buildContent(context, state.stats!)
          else
            const OdysseyEmptyState(
              icon: Icons.calendar_month_outlined,
              message: 'Nothing recorded for that year.',
            ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, YearInReviewStats stats) {
    final t = context.odyssey;
    final symbol = _symbolFor(stats.reportingCurrency);

    // Sorted, because a map arrives in whatever order it was built and a
    // chart of the year read 'Oct Sep Nov'. Anything unrecognised goes last
    // rather than being dropped or landing in January.
    final monthEntries = stats.tripsByMonth.entries.toList()
      ..sort((a, b) => _monthIndex(a.key).compareTo(_monthIndex(b.key)));
    final categorySegments = BarSegment.capped(
      (stats.expensesByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => BarSegment(label: e.key, value: e.value))
          .toList(),
    );

    return [
      HeroTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const EyebrowLabel(
              'Days on the road',
              color: AppColors.onAccentLabel,
            ),
            const SizedBox(height: AppSizes.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stats.totalDaysTraveled}',
                  style: AppTypography.statGiant.copyWith(
                    color: AppColors.onAccent,
                  ),
                ),
                const SizedBox(width: AppSizes.space8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    stats.totalDaysTraveled == 1 ? 'day' : 'days',
                    style: AppTypography.metaLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onAccent2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              stats.mostActiveMonth == null
                  ? 'across ${stats.totalTrips} trips'
                  : 'across ${stats.totalTrips} trips · busiest in '
                        '${stats.mostActiveMonth}',
              style: AppTypography.metaLarge.copyWith(
                color: AppColors.onAccent2,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.space12),

      Row(
        children: [
          Expanded(
            child: _Tile(label: 'Trips', value: '${stats.totalTrips}'),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: _Tile(label: 'Plans', value: '${stats.totalActivities}'),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.space12),
      Row(
        children: [
          Expanded(
            child: _Tile(label: 'Memories', value: '${stats.totalMemories}'),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: _Tile(
              label: 'Spent',
              value: TripFormat.compactMoney(stats.totalSpent, symbol),
            ),
          ),
        ],
      ),

      if (stats.unconvertedExpenseCount > 0) ...[
        const SizedBox(height: AppSizes.space10),
        Text(
          // The total is stated in one currency, so what is missing from it is
          // said plainly rather than quietly folded in.
          '${stats.unconvertedExpenseCount} expenses are left out of that '
          'total for want of a conversion rate.',
          style: AppTypography.rowMeta.copyWith(color: t.ink3),
        ),
      ],

      if (monthEntries.isNotEmpty) ...[
        const SizedBox(height: AppSizes.space12),
        OdysseyCard(
          radius: AppSizes.radiusHero,
          padding: const EdgeInsets.all(AppSizes.space18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EyebrowLabel('Trips by month'),
              const SizedBox(height: AppSizes.space18),
              BarChart(
                values: monthEntries.map((e) => e.value.toDouble()).toList(),
                // Three letters, not one: a single initial is ambiguous - June
                // and July are both 'J', March and May both 'M' - and it came
                // out lowercase besides. BarChart ellipsises anything that
                // still will not fit.
                labels: monthEntries.map((e) => _shortMonth(e.key)).toList(),
              ),
            ],
          ),
        ),
      ],

      if (categorySegments.isNotEmpty) ...[
        const SizedBox(height: AppSizes.space12),
        OdysseyCard(
          radius: AppSizes.radiusHero,
          padding: const EdgeInsets.all(AppSizes.space18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EyebrowLabel('Where it went'),
              const SizedBox(height: AppSizes.space16),
              SegmentedBar(
                segments: categorySegments,
                height: AppSizes.categoryBarHeight,
              ),
              const SizedBox(height: AppSizes.space14),
              BarLegend(segments: categorySegments),
            ],
          ),
        ),
      ],

      if (stats.destinationDataAvailable &&
          stats.topDestinations.isNotEmpty) ...[
        const SizedBox(height: AppSizes.space12),
        OdysseyCard(
          radius: AppSizes.radiusHero,
          padding: const EdgeInsets.all(AppSizes.space18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EyebrowLabel('Where you went'),
              const SizedBox(height: AppSizes.space16),
              for (var i = 0; i < stats.topDestinations.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSizes.space14),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.rampAt(i),
                        borderRadius: BorderRadius.circular(AppSizes.radiusDay),
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: Text(
                        stats.topDestinations[i],
                        style: AppTypography.rowTitle.copyWith(color: t.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  static const _months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];

  /// Where a month name falls in the year, or past the end if it is not one.
  static int _monthIndex(String month) {
    final i = _months.indexOf(month.trim().toLowerCase());
    return i == -1 ? _months.length : i;
  }

  /// 'september' to 'Sep'. The API's month names arrive in lower case.
  static String _shortMonth(String month) {
    if (month.isEmpty) return month;
    final short = month.length > 3 ? month.substring(0, 3) : month;
    return short[0].toUpperCase() + short.substring(1).toLowerCase();
  }

  Widget _buildPaywall(BuildContext context) {
    final t = context.odyssey;

    return OdysseyScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.contentTop,
          AppSizes.screenPadding,
          AppSizes.scrollBottom,
        ),
        children: [
          ScreenHeader(onBack: () => context.pop()),
          const SizedBox(height: AppSizes.space20),
          OdysseyCard(
            radius: AppSizes.radiusHero,
            padding: const EdgeInsets.all(AppSizes.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const EyebrowLabel('Pro'),
                const SizedBox(height: AppSizes.space12),
                Text(
                  'Year in review',
                  style: AppTypography.statSmall.copyWith(color: t.ink),
                ),
                const SizedBox(height: AppSizes.space10),
                Text(
                  'Everywhere you went, everything you did, in one page.',
                  style: AppTypography.subtitle.copyWith(color: t.ink2),
                ),
                const SizedBox(height: AppSizes.space18),
                PillButton(
                  label: 'See Pro',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    PaywallUtils.showPaywall(
                      context,
                      featureName: 'Year in Review',
                      unlockableFeature: PremiumFeature.yearInReview,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return OdysseyCard(
      radius: AppSizes.radiusHero,
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(label),
          const SizedBox(height: AppSizes.space14),
          Text(
            value,
            style: AppTypography.statMedium.copyWith(color: t.ink),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
