import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/task_routes.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../expenses/presentation/screens/expense_form_screen.dart';
import '../providers/trips_provider.dart';

/// The display name for a stored expense category, falling back to "Other"
/// for anything the app does not recognise.
String _categoryLabel(String raw) => ExpenseCategory.values
    .firstWhere((c) => c.name == raw, orElse: () => ExpenseCategory.other)
    .displayName;

/// The budget — screen 3i.
///
/// The total set very large, a four-tone category bar with its legend, the
/// remaining and per-day tiles, category chips, and the expense rows.
class TripExpensesTab extends ConsumerStatefulWidget {
  const TripExpensesTab({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripExpensesTab> createState() => _TripExpensesTabState();
}

class _TripExpensesTabState extends ConsumerState<TripExpensesTab> {
  static const String _allCategories = 'All';
  String _category = _allCategories;

  void _addExpense() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.expenseForm),
        builder: (context) => ExpenseFormScreen(tripId: widget.tripId),
      ),
    );
  }

  void _editExpense(ExpenseModel expense) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.expenseForm),
        builder: (context) =>
            ExpenseFormScreen(tripId: widget.tripId, expense: expense),
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete expense',
      body: ['This removes "${expense.title}" from the budget.'],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripExpensesProvider(widget.tripId).notifier)
        .deleteExpense(expense.id);
  }

  static String _symbolFor(String code) {
    for (final currency in commonCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(tripExpensesProvider(widget.tripId));
    final trip = ref.watch(tripProvider(widget.tripId)).asData?.value;

    if (state.isLoading && state.expenses.isEmpty) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 150, radius: AppSizes.radiusPanel),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
        ],
      );
    }

    if (state.error != null && state.expenses.isEmpty) {
      return OdysseyErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(tripExpensesProvider(widget.tripId).notifier).refresh(),
      );
    }

    if (state.expenses.isEmpty) {
      return OdysseyEmptyState(
        message: 'Nothing spent yet. It starts with the first coffee.',
        actionLabel: 'Add an expense',
        onAction: _addExpense,
      );
    }

    final symbol = _symbolFor(trip?.displayCurrency ?? 'USD');
    final budget = trip?.budget;

    // Category totals drive both the bar and the legend, so they are computed
    // once and ordered largest first — the ramp is ordered by emphasis, and a
    // bar whose loudest tone is its smallest slice reads as noise.
    final totals = <String, double>{};
    for (final expense in state.expenses) {
      final label = _categoryLabel(expense.category);
      totals[label] = (totals[label] ?? 0) + expense.amount;
    }
    final segments = BarSegment.capped(
      (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => BarSegment(label: e.key, value: e.value))
          .toList(),
    );

    final categories = <String>[_allCategories, ...segments.map((s) => s.label)];
    final visible = _category == _allCategories
        ? state.expenses
        : state.expenses
              .where((e) => _categoryLabel(e.category) == _category)
              .toList();

    final remaining = budget == null ? null : budget - state.totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- total ---
        OdysseyCard(
          radius: AppSizes.radiusPanel,
          padding: const EdgeInsets.all(AppSizes.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              EyebrowLabel(
                budget == null
                    ? 'Total spent'
                    : 'Spent of ${TripFormat.money(budget, symbol)}',
              ),
              const SizedBox(height: AppSizes.space12),
              Text(
                TripFormat.compactMoney(state.totalAmount, symbol),
                style: AppTypography.statTotal.copyWith(color: t.ink),
                maxLines: 1,
              ),
              const SizedBox(height: AppSizes.space18),
              SegmentedBar(
                segments: segments,
                height: AppSizes.categoryBarHeight,
              ),
              const SizedBox(height: AppSizes.space14),
              BarLegend(segments: segments),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space12),

        // --- remaining / per day ---
        Row(
          children: [
            Expanded(
              child: remaining == null
                  ? _Tile(
                      label: 'Expenses',
                      value: '${state.expenses.length}',
                      meta: 'no budget set',
                    )
                  : _LimeTile(
                      label: 'Remaining',
                      value: TripFormat.compactMoney(remaining, symbol),
                      meta: remaining >= 0 ? 'on track' : 'over budget',
                    ),
            ),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: _Tile(
                label: 'Largest',
                value: segments.isEmpty
                    ? '—'
                    : TripFormat.compactMoney(segments.first.value, symbol),
                meta: segments.isEmpty ? '' : segments.first.label.toLowerCase(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space18),

        if (categories.length > 2) ...[
          ChipRow(
            labels: categories,
            selected: _category,
            activeStyle: ChipActiveStyle.action,
            onSelected: (value) => setState(() => _category = value),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSizes.space16),
        ],

        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.space10),
          _ExpenseRow(
            expense: visible[i],
            symbol: symbol,
            // The chip takes the tone its category has in the bar above, so
            // the row and the chart agree on what colour "food" is. A category
            // folded into the bar's "Other" slice is not in the list, so it
            // takes that slice's tone.
            tone: t.rampAt(
              switch (segments.indexWhere(
                (s) => s.label == _categoryLabel(visible[i].category),
              )) {
                -1 => segments.length - 1,
                final index => index,
              },
            ),
            onTap: () => _editExpense(visible[i]),
            onLongPress: () => _deleteExpense(visible[i]),
          ),
        ],

        const SizedBox(height: AppSizes.space14),
        PillButton(
          label: 'Add an expense',
          style: PillStyle.dashed,
          onPressed: _addExpense,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ],
    );
  }
}

/// The lime summary tile — lime in both themes, like every hero stat.
class _LimeTile extends StatelessWidget {
  const _LimeTile({
    required this.label,
    required this.value,
    required this.meta,
  });

  final String label;
  final String value;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return HeroTile(
      radius: AppSizes.radiusTile,
      padding: const EdgeInsets.all(AppSizes.space18),
      showDecor: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(label, color: AppColors.onAccentLabel),
          const SizedBox(height: AppSizes.space10),
          Text(
            value,
            style: AppTypography.statCard.copyWith(color: AppColors.onAccent),
            maxLines: 1,
          ),
          const SizedBox(height: AppSizes.space6),
          Text(
            meta,
            style: AppTypography.pill.copyWith(color: AppColors.onAccent2),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.meta});

  final String label;
  final String value;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return OdysseyCard(
      radius: AppSizes.radiusTile,
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(label),
          const SizedBox(height: AppSizes.space10),
          Text(
            value,
            style: AppTypography.statCard.copyWith(color: t.ink),
            maxLines: 1,
          ),
          const SizedBox(height: AppSizes.space6),
          Text(meta, style: AppTypography.pill.copyWith(color: t.ink3)),
        ],
      ),
    );
  }
}

/// One expense: a category chip in its ramp tone, the title and meta, and the
/// amount set in the display face.
class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.symbol,
    required this.tone,
    required this.onTap,
    required this.onLongPress,
  });

  final ExpenseModel expense;
  final String symbol;
  final Color tone;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final date = TripFormat.parse(expense.date);

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expense.title,
                    style: AppTypography.rowTitle.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _categoryLabel(expense.category),
                      if (date != null) TripFormat.shortDate(date),
                    ].join(' · '),
                    style: AppTypography.rowMeta.copyWith(color: t.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TripFormat.money(expense.amount, symbol),
                  style: AppTypography.numeral.copyWith(
                    fontSize: 14,
                    color: t.ink,
                  ),
                ),
                if (expense.convertedAmount != null &&
                    expense.convertedCurrency != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${expense.convertedCurrency} '
                    '${expense.convertedAmount!.toStringAsFixed(0)}',
                    style: AppTypography.statLabel.copyWith(color: t.ink3),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
