import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../memories/presentation/providers/memories_provider.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../data/models/trip_model.dart';

/// The overview panel of trip detail.
///
/// Not a screen in the handoff, so it is built from the system: the From / To
/// pair, the notes, and a grouped card summarising what the other panels hold.
class TripOverviewTab extends ConsumerWidget {
  const TripOverviewTab({
    super.key,
    required this.trip,
    required this.duration,
  });

  final TripModel trip;
  final int duration;

  static String _symbolFor(String code) {
    for (final currency in commonCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.odyssey;

    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);
    final countdown = TripFormat.countdown(start, end);

    final activities = ref.watch(tripActivitiesProvider(trip.id));
    final packing = ref.watch(tripPackingProvider(trip.id));
    final expenses = ref.watch(tripExpensesProvider(trip.id));
    final documents = ref.watch(tripDocumentsProvider(trip.id));
    final memories = ref.watch(tripMemoriesProvider(trip.id));

    final symbol = _symbolFor(trip.displayCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ValueCard(
                label: 'From',
                value: start == null ? null : TripFormat.longDate(start),
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: ValueCard(
                label: 'To',
                value: end == null ? null : TripFormat.longDate(end),
              ),
            ),
          ],
        ),

        if (countdown != null) ...[
          const SizedBox(height: AppSizes.space12),
          OdysseyCard(
            radius: AppSizes.radiusRow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Expanded(child: EyebrowLabel('Status')),
                Text(
                  countdown,
                  style: AppTypography.caption.copyWith(color: t.ink),
                ),
              ],
            ),
          ),
        ],

        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space12),
          OdysseyCard(
            radius: AppSizes.radiusTile,
            padding: const EdgeInsets.all(AppSizes.space18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const EyebrowLabel('Notes'),
                const SizedBox(height: AppSizes.space10),
                Text(
                  trip.description!,
                  style: AppTypography.body.copyWith(color: t.ink2),
                ),
              ],
            ),
          ),
        ],

        if (trip.tags != null && trip.tags!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.space12),
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            children: [
              for (final tag in trip.tags!)
                OdysseyChip(label: tag, selected: false),
            ],
          ),
        ],

        const SizedBox(height: AppSizes.space18),
        const EyebrowLabel('In this trip'),
        const SizedBox(height: AppSizes.space12),

        // A count per panel, so the overview says what is actually in the trip
        // rather than repeating the stat row above it.
        GroupedCard(
          children: [
            _SummaryRow(
              label: 'Plans',
              value: '${activities.total}',
            ),
            _SummaryRow(
              label: 'Packing',
              value: packing.total == 0
                  ? 'No list'
                  : '${packing.packedCount} of ${packing.total} packed',
            ),
            _SummaryRow(
              label: 'Spend',
              value: expenses.expenses.isEmpty
                  ? 'Nothing yet'
                  : TripFormat.compactMoney(expenses.totalAmount, symbol),
            ),
            _SummaryRow(
              label: 'Documents',
              value: '${documents.documents.length}',
            ),
            _SummaryRow(
              label: 'Memories',
              value: '${memories.memories.length}',
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.rowLabel.copyWith(color: t.ink),
            ),
          ),
          Text(
            value,
            style: AppTypography.caption.copyWith(color: t.ink3),
          ),
        ],
      ),
    );
  }
}
