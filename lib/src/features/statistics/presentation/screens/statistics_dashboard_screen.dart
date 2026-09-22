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
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/statistics_model.dart';
import '../providers/statistics_provider.dart';

/// Statistics — screen 3l.
///
/// A bento grid: the lime days hero, two half tiles, a bar chart, and the
/// lists underneath. The range control switches what every number is about.
class StatisticsDashboardScreen extends ConsumerStatefulWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  ConsumerState<StatisticsDashboardScreen> createState() =>
      _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState
    extends ConsumerState<StatisticsDashboardScreen> {
  static const String _thisYear = 'This year';
  static const String _allTime = 'All time';

  String _range = _allTime;

  static String _symbolFor(String code) {
    for (final currency in commonCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(statisticsProvider);

    // Behind the paywall the range control switches between two sets of
    // numbers the user cannot see, so it is not offered.
    final gated = state.isPremiumRequired && state.statistics == null;

    return Scaffold(
      backgroundColor: t.canvas,
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => ref.read(statisticsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(onBack: () => context.pop()),
            const SizedBox(height: AppSizes.space20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Your\ntravel year',
                    style: AppTypography.screenTitle.copyWith(color: t.ink),
                  ),
                ),
                if (!gated)
                  SegmentedControl(
                    labels: const [_thisYear, _allTime],
                    selected: _range,
                    expand: false,
                    onSelected: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _range = value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.space20),

            if (state.isLoading && state.statistics == null)
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
            else if (gated)
              _PremiumGate(
                feature: state.premiumFeatureName ?? 'Full statistics',
                onTap: () => context.push(AppRoutes.subscription),
              )
            else if (state.error != null && state.statistics == null)
              OdysseyErrorState.fromError(
                state.error,
                message: 'Your statistics could not be loaded.',
                onRetry: () => ref.read(statisticsProvider.notifier).refresh(),
              )
            else if (state.statistics != null)
              ..._buildBento(state.statistics!)
            else
              const OdysseyEmptyState(
                icon: Icons.insights_outlined,
                message: 'Nothing to count yet. Take a trip.',
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBento(OverallStatistics stats) {
    final t = context.odyssey;
    final thisYear = _range == _thisYear;

    // "This year" is only as narrow as the API allows: it reports days ahead
    // and planned trips separately, but most figures come as lifetime totals.
    // Those keep their all-time value rather than being relabelled as a year's
    // worth of something they are not.
    final days = thisYear ? stats.plannedDaysAhead : stats.totalDaysOfTravel;
    final daysCaption = thisYear
        ? 'booked on trips still to come'
        : 'across every trip you have logged';

    // OverallStatistics carries no year breakdown, so the chart shows where
    // the money went — which is the other thing this screen is asked.
    final spendEntries =
        (stats.expensesByCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(6)
            .toList();

    return [
      // --- the lime hero ---
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
                  '$days',
                  style: AppTypography.statGiant.copyWith(
                    color: AppColors.onAccent,
                  ),
                ),
                const SizedBox(width: AppSizes.space8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    days == 1 ? 'day' : 'days',
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
              daysCaption,
              style: AppTypography.metaLarge.copyWith(
                color: AppColors.onAccent2,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.space12),

      // --- two halves ---
      Row(
        children: [
          Expanded(
            child: _BentoTile(
              label: 'Trips',
              value: '${thisYear ? stats.plannedTrips : stats.totalTrips}',
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: _BentoTile(
              label: stats.destinationDataAvailable ? 'Countries' : 'Memories',
              value: stats.destinationDataAvailable
                  ? '${stats.countriesVisited}'
                  : '${stats.totalMemories}',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.space12),

      // --- spend by category ---
      if (spendEntries.isNotEmpty) ...[
        OdysseyCard(
          radius: AppSizes.radiusHero,
          padding: const EdgeInsets.all(AppSizes.space18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: EyebrowLabel('Where it went')),
                  Text(
                    'largest highlighted',
                    style: AppTypography.badgeDesc.copyWith(color: t.ink3),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space18),
              BarChart(
                values: spendEntries.map((e) => e.value).toList(),
                // Passed whole. BarChart ellipsises what will not fit, which
                // is honest about having shortened it - chopping to five
                // characters here turned 'shopping' into 'shopp', which reads
                // as a typo rather than as a label that ran out of room.
                labels: spendEntries.map((e) => e.key).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space12),
      ],

      // --- spend ---
      OdysseyCard(
        radius: AppSizes.radiusHero,
        padding: const EdgeInsets.all(AppSizes.space18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EyebrowLabel('Total spend'),
            const SizedBox(height: AppSizes.space12),
            Text(
              TripFormat.compactMoney(
                stats.totalExpenseAmount,
                _symbolFor(stats.reportingCurrency),
              ),
              style: AppTypography.statSection.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              // The total is stated in one currency, so anything left out of
              // it is said plainly rather than quietly folded in.
              stats.unconvertedExpenseCount == 0
                  ? 'across ${stats.totalExpenses} expenses '
                        'in ${stats.reportingCurrency}'
                  : '${stats.unconvertedExpenseCount} expenses left out for '
                        'want of a conversion rate',
              style: AppTypography.rowMeta.copyWith(color: t.ink3),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.space12),

      // --- categories ---
      if (stats.activitiesByCategory.isNotEmpty)
        _RankedList(
          label: 'Most planned',
          entries: (stats.activitiesByCategory.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(5)
              .map((e) => (e.key, '${e.value}'))
              .toList(),
        ),

      if (stats.uniqueDestinations.isNotEmpty) ...[
        const SizedBox(height: AppSizes.space12),
        _RankedList(
          label: 'Destinations',
          entries: stats.uniqueDestinations
              .take(5)
              .map((d) => (d, ''))
              .toList(),
        ),
      ],

      const SizedBox(height: AppSizes.space18),
      PillButton(
        label: 'Year in review',
        onPressed: () => context.push('${AppRoutes.statistics}/year-review'),
      ),
    ];
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.label, required this.value});

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

/// A short ranked list: a ramp-toned chip, the label, and the count.
class _RankedList extends StatelessWidget {
  const _RankedList({required this.label, required this.entries});

  final String label;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyCard(
      radius: AppSizes.radiusHero,
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowLabel(label),
          const SizedBox(height: AppSizes.space16),
          for (var i = 0; i < entries.length; i++) ...[
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
                    entries[i].$1,
                    style: AppTypography.rowTitle.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entries[i].$2.isNotEmpty)
                  Text(
                    entries[i].$2,
                    style: AppTypography.numeral.copyWith(color: t.ink2),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.feature, required this.onTap});

  final String feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return OdysseyCard(
      radius: AppSizes.radiusHero,
      padding: const EdgeInsets.all(AppSizes.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel('Pro'),
          const SizedBox(height: AppSizes.space12),
          Text(
            feature,
            style: AppTypography.statSmall.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            'The full picture of where you have been is part of Pro.',
            style: AppTypography.subtitle.copyWith(color: t.ink2),
          ),
          const SizedBox(height: AppSizes.space18),
          PillButton(label: 'See Pro', onPressed: onTap),
        ],
      ),
    );
  }
}
