/// Date-range filtering that matches what the server does.
///
/// The server compares a trip's `StartDate` as a `DateOnly`, inclusive at both
/// ends. There is no time component in the comparison at all, so a trip starting
/// on the boundary day is included whatever hour its stored timestamp carries.
///
/// The local filter did not implement these at all: `_applyFilters` checked
/// search, status and tags and silently ignored `startDateFrom` and
/// `startDateTo`. Date filters therefore appeared to work on an uncached API
/// response and stopped working the moment the data was local — including every
/// offline use.
library;

/// A trip's start date reduced to a calendar day, or null if unparseable.
///
/// Tolerant on purpose: the field is a string, and has carried both a bare
/// `yyyy-MM-dd` and a full ISO timestamp over the app's life.
DateTime? startDayOf(String startDate) {
  final parsed = DateTime.tryParse(startDate);
  if (parsed == null) return null;

  // Local, not UTC. The user picked a calendar day in the filter UI, and a trip
  // starting on that day should match regardless of how its timestamp was
  // stored - converting to UTC first can shift the day either way.
  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(local.year, local.month, local.day);
}

/// Reduces a filter bound to a calendar day.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Whether a trip starting on [startDate] falls inside the range.
///
/// Both bounds are inclusive, matching the server's `>=` and `<=`. A trip whose
/// start date cannot be parsed is **kept**: dropping it would make a filter that
/// narrows a list also silently lose rows, which is worse than showing one more
/// than asked for.
bool matchesStartDateRange(
  String startDate, {
  DateTime? from,
  DateTime? to,
}) {
  if (from == null && to == null) return true;

  final day = startDayOf(startDate);
  if (day == null) return true;

  if (from != null && day.isBefore(dayOf(from))) return false;
  if (to != null && day.isAfter(dayOf(to))) return false;

  return true;
}
