import '../../memories/data/models/memory_model.dart';

/// Where a trip's map position came from.
enum TripLocationSource {
  /// Recorded coordinates on the trip's own memories — real data, from photos
  /// the user actually took.
  memoryCoordinates,

  /// Nothing recorded. The trip is still listed, and can be given a location.
  none,
}

/// A resolved position for one trip.
class ResolvedTripLocation {
  const ResolvedTripLocation({
    this.latitude,
    this.longitude,
    this.placeName,
    this.source = TripLocationSource.none,
  });

  final double? latitude;
  final double? longitude;

  /// A human-readable place, when a memory recorded one.
  final String? placeName;

  final TripLocationSource source;

  bool get hasLocation => latitude != null && longitude != null;
}

/// Resolves a trip's map position from data the user actually recorded.
///
/// This replaces matching the trip's title and description against a hard-coded
/// list of about thirty city names. That guessed both ways: a trip called
/// "Family holiday" had no match and was dropped from the map entirely, while a
/// description that merely mentioned Paris placed the trip in France.
///
/// Memories carry real coordinates from the photos attached to them, so they are
/// evidence rather than inference. A trip with none resolves to
/// [TripLocationSource.none] and is **kept** — the map can then offer to add a
/// location, instead of the trip silently disappearing.
ResolvedTripLocation resolveTripLocation(List<MemoryModel> tripMemories) {
  final located = tripMemories
      .where((m) => m.latitude != null && m.longitude != null)
      .toList();

  if (located.isEmpty) return const ResolvedTripLocation();

  // The earliest located memory, so a trip's pin is where it began rather than
  // wherever the most recent photo happened to be taken. Stable across new
  // memories being added, which matters for a pin the user learns the position
  // of.
  located.sort((a, b) {
    final aAt = DateTime.tryParse(a.takenAt ?? a.createdAt) ?? DateTime(1970);
    final bAt = DateTime.tryParse(b.takenAt ?? b.createdAt) ?? DateTime(1970);
    return aAt.compareTo(bAt);
  });

  final anchor = located.first;

  // A name only when one was recorded alongside the coordinates. Deriving a
  // place name from coordinates would be guessing again, one step removed.
  final named = located.firstWhere(
    (m) => (m.location ?? '').trim().isNotEmpty,
    orElse: () => anchor,
  );

  final placeName = (named.location ?? '').trim();

  return ResolvedTripLocation(
    latitude: anchor.latitude,
    longitude: anchor.longitude,
    placeName: placeName.isEmpty ? null : placeName,
    source: TripLocationSource.memoryCoordinates,
  );
}
