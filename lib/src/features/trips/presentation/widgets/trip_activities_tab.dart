import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/task_routes.dart';
import '../../../activities/data/models/activity_model.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../activities/presentation/providers/activity_done_provider.dart';
import '../../../activities/presentation/screens/activity_form_screen.dart';

/// The day plan — screen 3f.
///
/// A horizontal rail of the trip's days, then a timeline: a time gutter, a
/// rail with a dot and a hairline, and the activity card. Tapping a card marks
/// the plan done.
///
/// Tick state is device-local; see [ActivityDone] for why.
class TripActivitiesTab extends ConsumerStatefulWidget {
  const TripActivitiesTab({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripActivitiesTab> createState() => _TripActivitiesTabState();
}

class _TripActivitiesTabState extends ConsumerState<TripActivitiesTab> {
  static final DateFormat _time = DateFormat('HH:mm');

  /// Null means "every day at once", which is what the tab opens on when the
  /// activities span more than the trip's own dates or none are scheduled.
  DateTime? _selectedDay;

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// The days that actually have plans on them, in order.
  List<DateTime> _days(List<ActivityModel> activities) {
    final days = <DateTime>{};
    for (final activity in activities) {
      final when = DateTime.tryParse(activity.scheduledTime);
      if (when != null) days.add(_dayOf(when));
    }
    final sorted = days.toList()..sort();
    return sorted;
  }

  List<ActivityModel> _forDay(List<ActivityModel> activities, DateTime? day) {
    final list = day == null
        ? List<ActivityModel>.from(activities)
        : activities.where((a) {
            final when = DateTime.tryParse(a.scheduledTime);
            return when != null && _dayOf(when) == day;
          }).toList();

    list.sort((a, b) {
      final at = DateTime.tryParse(a.scheduledTime);
      final bt = DateTime.tryParse(b.scheduledTime);
      if (at == null || bt == null) return a.sortOrder.compareTo(b.sortOrder);
      return at.compareTo(bt);
    });
    return list;
  }

  void _addActivity() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.activityForm),
        builder: (context) => ActivityFormScreen(tripId: widget.tripId),
      ),
    );
  }

  void _editActivity(ActivityModel activity) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.activityForm),
        builder: (context) => ActivityFormScreen(
          tripId: widget.tripId,
          activity: activity,
        ),
      ),
    );
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete plan',
      body: ['This removes "${activity.title}" from the day. It cannot be undone.'],
      confirmLabel: 'Delete plan',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripActivitiesProvider(widget.tripId).notifier)
        .deleteActivity(activity.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(tripActivitiesProvider(widget.tripId));
    final done = ref.watch(activityDoneProvider(widget.tripId));

    if (state.isLoading && state.activities.isEmpty) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 74, radius: AppSizes.radiusMedium),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
        ],
      );
    }

    if (state.error != null && state.activities.isEmpty) {
      return OdysseyErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(tripActivitiesProvider(widget.tripId).notifier).refresh(),
      );
    }

    if (state.activities.isEmpty) {
      return OdysseyEmptyState(
        icon: Icons.event_note_outlined,
        message: 'No plans yet. Days fill up one idea at a time.',
        actionLabel: 'Add a plan',
        onAction: _addActivity,
      );
    }

    final days = _days(state.activities);
    final selected = _selectedDay != null && days.contains(_selectedDay)
        ? _selectedDay
        : null;
    final visible = _forDay(state.activities, selected);

    final doneCount = visible.where((a) => done.contains(a.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- day rail ---
        if (days.length > 1) ...[
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.space8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _RailItem(
                    top: 'ALL',
                    bottom: '${state.activities.length}',
                    selected: selected == null,
                    onTap: () => setState(() => _selectedDay = null),
                  );
                }
                final day = days[index - 1];
                return _RailItem(
                  top: TripFormat.weekday(day).toUpperCase(),
                  bottom: '${day.day}',
                  selected: selected == day,
                  onTap: () => setState(() => _selectedDay = day),
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.space18),
        ],

        // --- day heading ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                selected == null
                    ? 'Every plan'
                    : 'Day ${days.indexOf(selected) + 1} — '
                          '${TripFormat.shortDate(selected)}',
                style: AppTypography.statCard.copyWith(color: t.ink),
              ),
            ),
            Text(
              '$doneCount of ${visible.length} done',
              style: AppTypography.rowMeta.copyWith(color: t.ink3),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space16),

        // --- timeline ---
        for (var i = 0; i < visible.length; i++)
          _TimelineRow(
            activity: visible[i],
            isLast: i == visible.length - 1,
            done: done.contains(visible[i].id),
            time: _timeLabel(visible[i]),
            onToggle: () {
              HapticFeedback.selectionClick();
              ref
                  .read(activityDoneProvider(widget.tripId).notifier)
                  .toggle(visible[i].id);
            },
            onEdit: () => _editActivity(visible[i]),
            onDelete: () => _deleteActivity(visible[i]),
          ),

        // The footer pill is indented to line up with the cards rather than
        // with the time gutter.
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.timelineIndent),
          child: PillButton(
            label: 'Add to this day',
            style: PillStyle.dashed,
            onPressed: _addActivity,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  String _timeLabel(ActivityModel activity) {
    final when = DateTime.tryParse(activity.scheduledTime);
    return when == null ? '—' : _time.format(when);
  }
}

/// One day on the horizontal rail.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      tint: !selected,
      selected: selected,
      child: AnimatedContainer(
        duration: AppSizes.durationState,
        curve: AppSizes.curveState,
        width: AppSizes.railItemWidth,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? t.action : t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: selected ? Colors.transparent : t.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              top,
              style: AppTypography.microLabel.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: selected ? t.onAction : t.ink3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bottom,
              style: AppTypography.railDate.copyWith(
                // Inside a filled rail item the numeral takes the glyph colour
                // — ink on lime, lime on ink.
                color: selected ? t.actionGlyph : t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A time gutter, the rail with its dot and hairline, and the activity card.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.activity,
    required this.isLast,
    required this.done,
    required this.time,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ActivityModel activity;
  final bool isLast;
  final bool done;
  final String time;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSizes.timelineGutter,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                time,
                style: AppTypography.numeral.copyWith(color: t.ink2),
              ),
            ),
          ),

          SizedBox(
            width: AppSizes.timelineRail,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 22),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done ? t.action : t.ink3,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: t.hairline),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.space12),
              child: Pressable(
                onTap: onToggle,
                onLongPress: onEdit,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                tint: false,
                child: AnimatedContainer(
                  duration: AppSizes.durationState,
                  curve: AppSizes.curveState,
                  padding: const EdgeInsets.all(AppSizes.space16),
                  decoration: BoxDecoration(
                    color: done ? t.accentTint : t.card,
                    borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                    border: Border.all(
                      color: done ? t.accentTintBorder : t.hairline,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EyebrowLabel(activity.category, tight: true),
                            const SizedBox(height: AppSizes.space6),
                            Text(
                              activity.title,
                              style: AppTypography.cardTitleXl.copyWith(
                                color: done
                                    ? t.ink.withValues(alpha: 0.5)
                                    : t.ink,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: t.ink.withValues(alpha: 0.5),
                              ),
                            ),
                            if (activity.description != null &&
                                activity.description!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                activity.description!,
                                style: AppTypography.rowMeta.copyWith(
                                  color: t.ink3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.space12),
                      CircleCheckbox(
                        checked: done,
                        onChanged: (_) => onToggle(),
                        semanticLabel: activity.title,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
