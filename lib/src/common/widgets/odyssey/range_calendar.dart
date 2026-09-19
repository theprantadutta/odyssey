import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import '../../utils/trip_format.dart';
import 'pressable.dart';

/// The trip-date calendar from screen 3d.
///
/// A month grid inside a card. The selected range tints its middle days and
/// fills its endpoints with the theme's primary action colour, with the pill's
/// corners rounded only on its outer edges so a range reads as one shape.
///
/// Selection follows the prototype: the first tap sets the start and clears
/// the end; a later day sets the end; an earlier day restarts the range.
class RangeCalendar extends StatefulWidget {
  const RangeCalendar({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.initialMonth,
    this.firstDate,
    this.lastDate,
  });

  final DateTime? start;
  final DateTime? end;

  /// Fires on every tap with the new range. The end is null while a range is
  /// half-made.
  final void Function(DateTime? start, DateTime? end) onChanged;

  final DateTime? initialMonth;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<RangeCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final seed = widget.start ?? widget.initialMonth ?? DateTime.now();
    _visibleMonth = DateTime(seed.year, seed.month);
  }

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _step(int months) {
    HapticFeedback.selectionClick();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + months);
    });
  }

  bool _isDisabled(DateTime day) {
    final first = widget.firstDate;
    final last = widget.lastDate;
    if (first != null && day.isBefore(_dayOf(first))) return true;
    if (last != null && day.isAfter(_dayOf(last))) return true;
    return false;
  }

  void _select(DateTime day) {
    if (_isDisabled(day)) return;
    HapticFeedback.selectionClick();

    final start = widget.start;
    final end = widget.end;

    // No range yet, a complete range, or a tap before the start: begin again.
    if (start == null || end != null || day.isBefore(_dayOf(start))) {
      widget.onChanged(day, null);
      return;
    }

    // Tapping the start again clears it rather than making a zero-night trip.
    if (day.isAtSameMomentAs(_dayOf(start))) {
      widget.onChanged(null, null);
      return;
    }

    widget.onChanged(start, day);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    // DateTime.weekday is 1 (Mon) to 7 (Sun); the grid starts on Monday, so
    // the blanks before the first are simply weekday - 1.
    final leadingBlanks = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).weekday - 1;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  TripFormat.monthYear(_visibleMonth),
                  style: AppTypography.button.copyWith(color: t.ink),
                ),
              ),
              _MonthStep(glyph: '←', onTap: () => _step(-1), label: 'Previous month'),
              const SizedBox(width: AppSizes.space8),
              _MonthStep(glyph: '→', onTap: () => _step(1), label: 'Next month'),
            ],
          ),
          const SizedBox(height: AppSizes.space14),

          Row(
            children: [
              for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.space6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.microLabel.copyWith(color: t.ink3),
                    ),
                  ),
                ),
            ],
          ),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: AppSizes.space4,
              crossAxisSpacing: AppSizes.space4,
              mainAxisExtent: AppSizes.dayCellHeight,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();

              final day = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                index - leadingBlanks + 1,
              );
              return _DayCell(
                day: day,
                start: widget.start,
                end: widget.end,
                disabled: _isDisabled(day),
                onTap: () => _select(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthStep extends StatelessWidget {
  const _MonthStep({
    required this.glyph,
    required this.onTap,
    required this.label,
  });

  final String glyph;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          glyph,
          style: AppTypography.glyph.copyWith(fontSize: 15, color: t.ink3),
        ),
      ),
    );
  }
}

/// One day. Its shape carries its place in the range: the outer edges of the
/// pill are rounded, the inside is square, so a run of days reads as one bar.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.start,
    required this.end,
    required this.disabled,
    required this.onTap,
  });

  final DateTime day;
  final DateTime? start;
  final DateTime? end;
  final bool disabled;
  final VoidCallback onTap;

  static DateTime _d(DateTime v) => DateTime(v.year, v.month, v.day);

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final isStart = start != null && _d(day) == _d(start!);
    final isEnd = end != null && _d(day) == _d(end!);
    final isMiddle =
        start != null &&
        end != null &&
        day.isAfter(_d(start!)) &&
        day.isBefore(_d(end!));
    final isEndpoint = isStart || isEnd;
    final isToday = _d(day) == _d(DateTime.now());

    final BorderRadius radius;
    if (isStart && isEnd) {
      radius = BorderRadius.circular(AppSizes.radiusDayEnd);
    } else if (isStart && end != null) {
      radius = const BorderRadius.horizontal(
        left: Radius.circular(AppSizes.radiusDayEnd),
        right: Radius.circular(AppSizes.radiusDayMid),
      );
    } else if (isEnd) {
      radius = const BorderRadius.horizontal(
        left: Radius.circular(AppSizes.radiusDayMid),
        right: Radius.circular(AppSizes.radiusDayEnd),
      );
    } else if (isMiddle) {
      radius = BorderRadius.circular(AppSizes.radiusDayMid);
    } else if (isStart) {
      // A half-made range: the start is a single pill until an end is chosen.
      radius = BorderRadius.circular(AppSizes.radiusDayEnd);
    } else {
      radius = BorderRadius.circular(AppSizes.radiusDay);
    }

    final Color background;
    final Color foreground;
    if (isEndpoint) {
      background = t.action;
      foreground = t.onAction;
    } else if (isMiddle) {
      background = t.rangeFill;
      foreground = t.ink;
    } else {
      background = Colors.transparent;
      foreground = disabled
          ? t.ink3
          : (t.isDark
                ? const Color(0xB3F2F2EF)
                : const Color(0xB30A0B0D));
    }

    return Semantics(
      selected: isEndpoint || isMiddle,
      button: !disabled,
      label: TripFormat.longDate(day),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppSizes.durationState,
          curve: AppSizes.curveState,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            // Today is marked with a hairline rather than a fill, so it never
            // competes with the range.
            border: isToday && !isEndpoint && !isMiddle
                ? Border.all(color: t.hairlineStrong)
                : null,
          ),
          child: Opacity(
            opacity: disabled ? 0.35 : 1,
            child: Text(
              '${day.day}',
              style: AppTypography.chip.copyWith(
                fontSize: 13,
                fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
