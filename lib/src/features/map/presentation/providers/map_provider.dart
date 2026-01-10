import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../trips/data/models/trip_model.dart';
import '../../../trips/data/repositories/trip_repository.dart';

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
  });

  factory TripLocation.fromTrip(TripModel trip) {
    // Try to find location from title and description
    // In production, you would use a geocoding service
    final searchText = '${trip.title} ${trip.description ?? ''}';
    final coords = _getCoordinatesFromText(searchText);
    final destination = _extractDestination(searchText);

    return TripLocation(
      tripId: trip.id,
      title: trip.title,
      destination: destination,
      status: trip.status,
      coverImageUrl: trip.coverImageUrl,
      latitude: coords?['lat'],
      longitude: coords?['lng'],
      startDate: trip.startDate,
      endDate: trip.endDate,
    );
  }

  static String? _extractDestination(String text) {
    final lowerText = text.toLowerCase();
    final destinations = [
      'Paris',
      'London',
      'New York',
      'Tokyo',
      'Sydney',
      'Rome',
      'Barcelona',
      'Bangkok',
      'Dubai',
      'Singapore',
      'Dhaka',
      "Cox's Bazar",
      'Chittagong',
      'Sylhet',
      'Los Angeles',
      'Berlin',
      'Amsterdam',
      'Istanbul',
      'Cairo',
      'Mumbai',
      'Delhi',
      'Bali',
      'Maldives',
      'Hong Kong',
      'Seoul',
      'Kuala Lumpur',
      'San Francisco',
      'Miami',
      'Las Vegas',
    ];

    for (final dest in destinations) {
      if (lowerText.contains(dest.toLowerCase())) {
        return dest;
      }
    }
    return null;
  }

  static Map<String, double>? _getCoordinatesFromText(String? text) {
    if (text == null) return null;

    // Sample coordinates for common destinations
    // In production, use a geocoding service
    final coords = <String, Map<String, double>>{
      'paris': {'lat': 48.8566, 'lng': 2.3522},
      'london': {'lat': 51.5074, 'lng': -0.1278},
      'new york': {'lat': 40.7128, 'lng': -74.0060},
      'tokyo': {'lat': 35.6762, 'lng': 139.6503},
      'sydney': {'lat': -33.8688, 'lng': 151.2093},
      'rome': {'lat': 41.9028, 'lng': 12.4964},
      'barcelona': {'lat': 41.3851, 'lng': 2.1734},
      'bangkok': {'lat': 13.7563, 'lng': 100.5018},
      'dubai': {'lat': 25.2048, 'lng': 55.2708},
      'singapore': {'lat': 1.3521, 'lng': 103.8198},
      'dhaka': {'lat': 23.8103, 'lng': 90.4125},
      'cox\'s bazar': {'lat': 21.4272, 'lng': 92.0058},
      'chittagong': {'lat': 22.3569, 'lng': 91.7832},
      'sylhet': {'lat': 24.8949, 'lng': 91.8687},
      'los angeles': {'lat': 34.0522, 'lng': -118.2437},
      'berlin': {'lat': 52.5200, 'lng': 13.4050},
      'amsterdam': {'lat': 52.3676, 'lng': 4.9041},
      'istanbul': {'lat': 41.0082, 'lng': 28.9784},
      'cairo': {'lat': 30.0444, 'lng': 31.2357},
      'mumbai': {'lat': 19.0760, 'lng': 72.8777},
      'delhi': {'lat': 28.7041, 'lng': 77.1025},
      'bali': {'lat': -8.3405, 'lng': 115.0920},
      'maldives': {'lat': 3.2028, 'lng': 73.2207},
      'hong kong': {'lat': 22.3193, 'lng': 114.1694},
      'seoul': {'lat': 37.5665, 'lng': 126.9780},
      'kuala lumpur': {'lat': 3.1390, 'lng': 101.6869},
      'san francisco': {'lat': 37.7749, 'lng': -122.4194},
      'miami': {'lat': 25.7617, 'lng': -80.1918},
      'las vegas': {'lat': 36.1699, 'lng': -115.1398},
    };

    final lowerDest = text.toLowerCase();
    for (final entry in coords.entries) {
      if (lowerDest.contains(entry.key)) {
        return entry.value;
      }
    }

    // Return null if no match - use random offset from a base location
    // In production, call a geocoding API
    return null;
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

  Future<void> _loadTrips() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repository = TripRepository();
      final response = await repository.getTrips(pageSize: 100);

      final locations = response.trips
          .map((trip) => TripLocation.fromTrip(trip))
          .where((loc) => loc.hasLocation)
          .toList();

      state = state.copyWith(tripLocations: locations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadTrips();
  }
}
