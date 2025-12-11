import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/trip_model.dart';
import '../../data/repositories/trip_repository.dart';

part 'trips_provider.g.dart';

/// Trips state
class TripsState {
  final List<TripModel> trips;
  final bool isLoading;
  final String? error;
  final int total;
  final int currentPage;
  final bool hasMore;

  const TripsState({
    this.trips = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
  });

  TripsState copyWith({
    List<TripModel>? trips,
    bool? isLoading,
    String? error,
    int? total,
    int? currentPage,
    bool? hasMore,
  }) {
    return TripsState(
      trips: trips ?? this.trips,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Trip repository provider
@riverpod
TripRepository tripRepository(Ref ref) {
  return TripRepository();
}

/// Trips list provider
@riverpod
class Trips extends _$Trips {
  late final TripRepository _tripRepository;

  @override
  TripsState build() {
    _tripRepository = ref.read(tripRepositoryProvider);
    _loadTrips();
    return const TripsState();
  }

  /// Load trips (first page)
  Future<void> _loadTrips() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _tripRepository.getTrips(page: 1);
      state = state.copyWith(
        trips: response.trips,
        total: response.total,
        currentPage: 1,
        hasMore: response.trips.length < response.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh trips
  Future<void> refresh() async {
    await _loadTrips();
  }

  /// Load more trips (pagination)
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true);
    try {
      final nextPage = state.currentPage + 1;
      final response = await _tripRepository.getTrips(page: nextPage);

      final allTrips = [...state.trips, ...response.trips];
      state = state.copyWith(
        trips: allTrips,
        total: response.total,
        currentPage: nextPage,
        hasMore: allTrips.length < response.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create trip
  Future<void> createTrip(TripRequest request) async {
    try {
      final newTrip = await _tripRepository.createTrip(request);
      state = state.copyWith(
        trips: [newTrip, ...state.trips],
        total: state.total + 1,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update trip
  Future<void> updateTrip(String id, Map<String, dynamic> updates) async {
    try {
      final updatedTrip = await _tripRepository.updateTrip(id, updates);
      final updatedTrips = state.trips.map((trip) {
        return trip.id == id ? updatedTrip : trip;
      }).toList();

      state = state.copyWith(trips: updatedTrips);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete trip
  Future<void> deleteTrip(String id) async {
    try {
      await _tripRepository.deleteTrip(id);
      final updatedTrips = state.trips.where((trip) => trip.id != id).toList();

      state = state.copyWith(
        trips: updatedTrips,
        total: state.total - 1,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Single trip provider (for detail view)
@riverpod
class Trip extends _$Trip {
  late final TripRepository _tripRepository;

  @override
  Future<TripModel?> build(String tripId) async {
    _tripRepository = ref.read(tripRepositoryProvider);
    return await _loadTrip(tripId);
  }

  Future<TripModel?> _loadTrip(String tripId) async {
    try {
      return await _tripRepository.getTripById(tripId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh single trip
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadTrip(tripId));
  }
}
