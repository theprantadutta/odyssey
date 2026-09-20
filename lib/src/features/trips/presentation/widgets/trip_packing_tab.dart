import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/task_routes.dart';
import '../../../packing/data/models/packing_model.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../../packing/presentation/screens/packing_item_form_screen.dart';

/// The packing list — screen 3h.
///
/// A lime progress hero that recomputes live, group chips, and item rows whose
/// packed state is the same lime tint and strike-through the day plan uses.
class TripPackingTab extends ConsumerStatefulWidget {
  const TripPackingTab({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripPackingTab> createState() => _TripPackingTabState();
}

class _TripPackingTabState extends ConsumerState<TripPackingTab> {
  static const String _allGroups = 'All';
  String _group = _allGroups;

  void _addItem() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.packingItemForm),
        builder: (context) => PackingItemFormScreen(tripId: widget.tripId),
      ),
    );
  }

  void _editItem(PackingItemModel item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.packingItemForm),
        builder: (context) =>
            PackingItemFormScreen(tripId: widget.tripId, item: item),
      ),
    );
  }

  Future<void> _deleteItem(PackingItemModel item) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Remove item',
      body: ['This takes "${item.name}" off the packing list.'],
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripPackingProvider(widget.tripId).notifier)
        .deletePackingItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripPackingProvider(widget.tripId));

    if (state.isLoading && state.items.isEmpty) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 190, radius: AppSizes.radiusHero),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
        ],
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return OdysseyErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(tripPackingProvider(widget.tripId).notifier).refresh(),
      );
    }

    if (state.items.isEmpty) {
      return OdysseyEmptyState(
        icon: Icons.checklist_rounded,
        message: 'Nothing on the list yet. Start with what you would miss.',
        actionLabel: 'Add an item',
        onAction: _addItem,
      );
    }

    // The hero always reports the whole list, not the filtered view — the
    // question it answers is "am I packed", which a group filter should not
    // change the answer to.
    final total = state.items.length;
    final packed = state.items.where((i) => i.isPacked).length;
    final percent = total == 0 ? 0 : (packed / total * 100).round();

    final groups = <String>{
      _allGroups,
      ...state.items.map((i) => _groupLabel(i.category)),
    }.toList();

    final visible = _group == _allGroups
        ? state.items
        : state.items
              .where((i) => _groupLabel(i.category) == _group)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressHero(
          percent: percent,
          packed: packed,
          total: total,
        ),
        const SizedBox(height: AppSizes.space18),

        if (groups.length > 2) ...[
          ChipRow(
            labels: groups,
            selected: _group,
            activeStyle: ChipActiveStyle.action,
            onSelected: (value) => setState(() => _group = value),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSizes.space16),
        ],

        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.space10),
          _PackingRow(
            item: visible[i],
            onToggle: () {
              HapticFeedback.selectionClick();
              ref
                  .read(tripPackingProvider(widget.tripId).notifier)
                  .togglePackedStatus(visible[i].id);
            },
            onEdit: () => _editItem(visible[i]),
            onDelete: () => _deleteItem(visible[i]),
          ),
        ],

        const SizedBox(height: AppSizes.space14),
        PillButton(
          label: 'Add an item',
          style: PillStyle.dashed,
          onPressed: _addItem,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ],
    );
  }

  /// The mono row tags are short by design, so a long category name is cut to
  /// its first word rather than wrapped.
  static String _groupLabel(String category) {
    final parsed = PackingCategory.values.firstWhere(
      (c) => c.name == category,
      orElse: () => PackingCategory.other,
    );
    return parsed.displayName;
  }
}

/// The lime hero. Stays lime in both themes, like every other hero stat tile.
class _ProgressHero extends StatelessWidget {
  const _ProgressHero({
    required this.percent,
    required this.packed,
    required this.total,
  });

  final int percent;
  final int packed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return HeroTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel(
            'Carry-on ready',
            color: AppColors.onAccentLabel,
          ),
          const SizedBox(height: AppSizes.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$percent',
                style: AppTypography.statHuge.copyWith(
                  fontSize: 60,
                  color: AppColors.onAccent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '%',
                  style: AppTypography.statHuge.copyWith(
                    fontSize: 15,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          ProgressTrack(
            value: total == 0 ? 0 : packed / total,
            trackColor: AppColors.onAccentTrack,
            fillColor: AppColors.onAccent,
          ),
          const SizedBox(height: AppSizes.space12),
          Row(
            children: [
              Text(
                '$packed of $total packed',
                style: AppTypography.pill.copyWith(
                  color: AppColors.onAccent2,
                ),
              ),
              const Spacer(),
              Text(
                total - packed == 0 ? 'All in' : '${total - packed} to go',
                style: AppTypography.pill.copyWith(
                  color: AppColors.onAccent2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One item: a circular checkbox, the name and quantity, and a mono category
/// tag. Packed reads exactly as "done" does on the day plan.
class _PackingRow extends StatelessWidget {
  const _PackingRow({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PackingItemModel item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final packed = item.isPacked;

    return Pressable(
      onTap: onToggle,
      onLongPress: onEdit,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      tint: false,
      child: AnimatedContainer(
        duration: AppSizes.durationState,
        curve: AppSizes.curveState,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: packed ? t.accentTint : t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(
            color: packed ? t.accentTintBorder : t.hairline,
          ),
        ),
        child: Row(
          children: [
            CircleCheckbox(
              checked: packed,
              size: AppSizes.checkboxSmall,
              onChanged: (_) => onToggle(),
              semanticLabel: item.name,
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.rowTitle.copyWith(
                      color: packed ? t.ink.withValues(alpha: 0.5) : t.ink,
                      decoration: packed ? TextDecoration.lineThrough : null,
                      decorationColor: t.ink.withValues(alpha: 0.5),
                    ),
                  ),
                  if (item.quantity > 1 ||
                      (item.notes != null && item.notes!.isNotEmpty)) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.quantity > 1) '×${item.quantity}',
                        if (item.notes != null && item.notes!.isNotEmpty)
                          item.notes!,
                      ].join(' · '),
                      style: AppTypography.rowMeta.copyWith(color: t.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            MonoTag(_shortTag(item.category)),
          ],
        ),
      ),
    );
  }

  /// The mono row tag, as a four-letter code.
  ///
  /// Truncating the display name gave "OTHE" and "TOIL", which read as typos.
  /// These are chosen words, the way the design's own DOCS / TECH / WEAR / CARE
  /// are.
  static String _shortTag(String category) =>
      switch (PackingCategory.values.firstWhere(
        (c) => c.name == category,
        orElse: () => PackingCategory.other,
      )) {
        PackingCategory.clothes => 'WEAR',
        PackingCategory.toiletries => 'CARE',
        PackingCategory.electronics => 'TECH',
        PackingCategory.documents => 'DOCS',
        PackingCategory.medicine => 'MEDS',
        PackingCategory.other => 'MISC',
      };
}
