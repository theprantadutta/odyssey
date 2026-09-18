/// The revision an update is being made against.
///
/// Sent to the server as `_base_version` so it can tell "this edit was made
/// against what I currently hold" from "this edit was made against something
/// older, and somebody has changed it since".
///
/// That only works if the value is byte-identical to what the server issued.
/// Drift stores a `DateTime` as unix **seconds**, while PostgreSQL keeps
/// microseconds, so a revision round-tripped through `updatedAt` comes back
/// truncated - a server revision ending `.321` returns as `.000`. The server
/// then sees a base version older than its own row and reports a conflict on a
/// record nobody else has touched.
///
/// The exact string is therefore kept beside the timestamp, in
/// `serverRevision`, and used here in preference to it.
library;

/// Reads the base version to send for [row].
///
/// [row] is a Drift row for any synced entity. It is `dynamic` because the
/// generated row classes share no supertype, and the alternative - an overload
/// per entity - is seven copies of two lines that must not drift apart.
///
/// Falls back to the local timestamp when no server revision is recorded, which
/// is the case for a row created on this device and never yet acknowledged, and
/// for rows written before the column existed. Those are exactly the cases
/// where the server has nothing to compare against anyway.
String? baseVersionOf(dynamic row) {
  if (row == null) return null;

  final revision = row.serverRevision as String?;
  if (revision != null && revision.isNotEmpty) return revision;

  final updatedAt = row.updatedAt;

  // `.toUtc()` is not decoration. Drift stores a DateTime as a unix timestamp
  // and hands it back in the device's **local** zone, so `toIso8601String()`
  // alone produces something like `2026-05-01T16:00:00.000` - local time, with
  // no zone marker at all. Sent as a base version that is read as UTC, which
  // is wrong by the device's offset in whichever direction the user happens to
  // live, and silently correct only in London in winter.
  if (updatedAt is DateTime) return updatedAt.toUtc().toIso8601String();
  if (updatedAt is String) return updatedAt;

  return null;
}
