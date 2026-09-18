import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../memories/data/models/memory_model.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/data/repositories/trip_repository.dart';
import '../../domain/trip_location_resolver.dart';

part 'map_provider.g.dart';

/// Trip location for map display
class TripLocation {
  final String tripId;
  final String title;
  final String? destination;
  final String status;
  final String? coverImageUrl;
  final double? latitude;
  final double? longitude;
  final String startDate;
  final String endDate;

  /// Where the position came from, or that there isn't one.
  final TripLocationSource source;

  const TripLocation({
    required this.tripId,
    required this.title,
    this.destination,
    required this.status,
    this.coverImageUrl,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    this.source = TripLocationSource.none,
  });

  /// Builds a map entry from a trip and whatever locations it actually has.
  ///
  /// [resolved] comes from the trip's own memories - coordinates recorded on the
  /// photos the user took. The previous version matched the title and
  /// description against a hard-coded list of about thirty cities, which guessed
  /// in both directions: a trip called "Family holiday" matched nothing and
  /// vanished from the map, while a description that merely mentioned Paris put
  /// the trip in France.
  factory TripLocation.fromTrip(TripModel trip, ResolvedTripLocation resolved) {
    return TripLocation(
      tripId: trip.id,
      title: trip.title,
      destination: resolved.placeName,
      status: trip.status,
      coverImageUrl: trip.coverImageUrl,
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      startDate: trip.startDate,
      endDate: trip.endDate,
      source: resolved.source,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}

/// Map state
class MapState {
  final List<TripLocation> tripLocations;
  final bool isLoading;
  final String? error;

  const MapState({
    this.tripLocations = const [],
    this.isLoading = false,
    this.error,
  });

  MapState copyWith({
    List<TripLocation>? tripLocations,
    bool? isLoading,
    String? error,
  }) {
    return MapState(
      tripLocations: tripLocations ?? this.tripLocations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalTrips => tripLocations.length;

  int get tripsWithLocation => tripLocations.where((t) => t.hasLocation).length;

  /// Trips the map can actually place.
  List<TripLocation> get mappable =>
      tripLocations.where((t) => t.hasLocation).toList();

  /// Trips with nothing recorded to place them by.
  ///
  /// Kept and surfaced rather than filtered away. Dropping them is what made a
  /// trip disappear from the map with no explanation and nothing to do about it.
  List<TripLocation> get unmapped =>
      tripLocations.where((t) => !t.hasLocation).toList();

  Set<String> get uniqueDestinations => tripLocations
      .where((t) => t.destination != null)
      .map((t) => t.destination!)
      .toSet();

  List<TripLocation> get plannedTrips =>
      tripLocations.where((t) => t.status == 'planned').toList();

  List<TripLocation> get ongoingTrips =>
      tripLocations.where((t) => t.status == 'ongoing').toList();

  List<TripLocation> get completedTrips =>
      tripLocations.where((t) => t.status == 'completed').toList();
}

/// Map trips provider
@Riverpod(keepAlive: true)
class MapTrips extends _$MapTrips {
  @override
  MapState build() {
    Future.microtask(() => _loadTrips());
    return const MapState();
  }

  /// How many trips the map will ask for.
  ///
  /// The map used to request exactly one page of 100 and show whatever came
  /// back, so a user past that simply never saw their older trips.
  static const int _pageSize = 100;
  static const int _maxPages = 20;

  Future<void> _loadTrips() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = TripRepository();
      final database = DatabaseService().database;

      final trips = <TripModel>[];

      for (var page = 1; page <= _maxPages; page++) {
        final response = await repository.getTrips(page: page, pageSize: _pageSize);
        trips.addAll(response.trips);

        if (trips.length >= response.total || response.trips.isEmpty) break;
      }

      // Read once and grouped, rather than a query per trip.
      final memories = await database.memoriesDao.getAll();
      final byTrip = <String, List<MemoryModel>>{};

      for (final row in memories) {
        (byTrip[row.tripId] ??= <MemoryModel>[]).add(memoryFromLocal(row));
      }

      final locations = trips
          .map((trip) => TripLocation.fromTrip(
                trip,
                resolveTripLocation(byTrip[trip.id] ?? const <MemoryModel>[]),
              ))
          .toList();

      // Note what is *not* here: no filter on hasLocation. A trip without
      // coordinates stays in the list so the map can say so and offer to fix it.
      state = state.copyWith(tripLocations: locations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadTrips();
  }
}
