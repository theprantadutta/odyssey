import 'package:intl/intl.dart';

import '../../features/trips/data/models/trip_model.dart';

/// Formatting helpers shared by the redesigned screens.
///
/// Trip dates arrive from the API as ISO strings, and several screens need the
/// same derived facts — how many nights, how far out, which day of the trip
/// today is. Deriving them in one place keeps the home hero, the trip card and
/// the trip detail cover from disagreeing with each other.
class TripFormat {
  TripFormat._();

  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _dayOnly = DateFormat('d');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _fullDate = DateFormat('d MMMM yyyy');
  static final DateFormat _weekday = DateFormat('EEE');

  /// Parses an API date string, tolerating a null or malformed value.
  static DateTime? parse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Midnight today, for day-count arithmetic that should ignore the clock.
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// `4 Oct`
  static String shortDate(DateTime? date) =>
      date == null ? '—' : _dayMonth.format(date);

  /// `4 October 2026`
  static String longDate(DateTime? date) =>
      date == null ? '—' : _fullDate.format(date);

  /// `October 2026`
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// `Mon`
  static String weekday(DateTime date) => _weekday.format(date);

  /// The cover line on a trip detail screen: `4 — 14 October 2026`.
  ///
  /// Collapses to a single month when the range does not cross one, which is
  /// how the design renders it.
  static String dateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Dates not set';
    if (start == null) return longDate(end);
    if (end == null) return longDate(start);

    if (start.year == end.year && start.month == end.month) {
      return '${_dayOnly.format(start)} — ${_fullDate.format(end)}';
    }
    if (start.year == end.year) {
      return '${_dayMonth.format(start)} — ${_fullDate.format(end)}';
    }
    return '${_fullDate.format(start)} — ${_fullDate.format(end)}';
  }

  /// Nights between two dates, floored at zero.
  static int nights(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 0;
    final diff = end.difference(start).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Days until a trip starts. Negative once it has begun, null without a date.
  static int? daysUntil(DateTime? start) {
    if (start == null) return null;
    return DateTime(start.year, start.month, start.day)
        .difference(_today)
        .inDays;
  }

  /// The countdown pill copy: `14 days out`, `Tomorrow`, `Today`, `Day 3 of 6`,
  /// `Completed`, `Under way`.
  static String? countdown(DateTime? start, DateTime? end) {
    final days = daysUntil(start);
    if (days == null) return null;
    if (days > 1) return '$days days out';
    if (days == 1) return 'Tomorrow';
    if (days == 0) return 'Today';

    // Already started — say where we are in it rather than counting backwards.
    final progress = dayProgress(start, end);
    if (progress != null) return 'Day ${progress.$1} of ${progress.$2}';

    // Past its end date. dayProgress only answers for a day inside the trip, so
    // without this a trip that finished last week still read 'Under way'.
    if (end != null && DateTime(end.year, end.month, end.day).isBefore(_today)) {
      return 'Completed';
    }

    // Started, with no end date to have passed: genuinely still going.
    return 'Under way';
  }

  /// `(3, 6)` for the third day of a six-day trip, or null when today falls
  /// outside the range.
  static (int, int)? dayProgress(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final total = nights(start, end) + 1;
    if (total <= 0) return null;

    final elapsed =
        _today.difference(DateTime(start.year, start.month, start.day)).inDays;
    if (elapsed < 0 || elapsed >= total) return null;
    return (elapsed + 1, total);
  }

  /// The meta line under a trip on the home hero: `4 Oct · 10 nights`.
  static String tripMeta(TripModel trip, {int? planCount}) {
    final start = parse(trip.startDate);
    final end = parse(trip.endDate);
    final parts = <String>[
      if (start != null) shortDate(start),
      if (start != null && end != null) '${nights(start, end)} nights',
      if (planCount != null && planCount > 0) '$planCount plans',
    ];
    return parts.isEmpty ? 'Dates not set' : parts.join(' · ');
  }

  /// True when today sits inside the trip's date range.
  static bool isActive(TripModel trip) =>
      dayProgress(parse(trip.startDate), parse(trip.endDate)) != null;

  /// The trip the home hero should feature: the one under way, else the next
  /// one starting, else the most recent.
  static TripModel? nextTrip(List<TripModel> trips) {
    if (trips.isEmpty) return null;

    final active = trips.where(isActive).toList();
    if (active.isNotEmpty) return active.first;

    final upcoming = trips
        .where((t) => (daysUntil(parse(t.startDate)) ?? -1) >= 0)
        .toList()
      ..sort((a, b) => (daysUntil(parse(a.startDate)) ?? 0)
          .compareTo(daysUntil(parse(b.startDate)) ?? 0));
    if (upcoming.isNotEmpty) return upcoming.first;

    return trips.first;
  }

  /// A compact money string — `¥148k`, `$992`, `৳1.2m`.
  ///
  /// The design sets these enormous, so the whole point is to keep them short.
  static String compactMoney(num amount, String symbol) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}m';
    }
    if (abs >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
    }
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  /// A money string at full precision with thousands separators.
  static String money(num amount, String symbol) {
    return '$symbol${NumberFormat('#,##0').format(amount)}';
  }

  /// `2,480` — the leaderboard and points figures.
  static String number(num value) => NumberFormat('#,##0').format(value);
}
