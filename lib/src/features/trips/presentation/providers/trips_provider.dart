import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
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
  TripRepository get _tripRepository => ref.read(tripRepositoryProvider);

  @override
  TripsState build() {
    // Defer the initial load to run after build() completes
    // This prevents "uninitialized provider" error in Riverpod 3
    Future.microtask(() => _loadTrips());
    return const TripsState();
  }

  /// Load trips (first page)
  Future<void> _loadTrips() async {
    AppLogger.state('Trips', 'Loading trips (page 1)');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _tripRepository.getTrips(page: 1);
      AppLogger.state('Trips', 'Loaded ${response.trips.length} trips (total: ${response.total})');
      state = state.copyWith(
        trips: response.trips,
        total: response.total,
        currentPage: 1,
        hasMore: response.trips.length < response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load trips: $e');
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

    final nextPage = state.currentPage + 1;
    AppLogger.state('Trips', 'Loading more trips (page $nextPage)');
    state = state.copyWith(isLoading: true);
    try {
      final response = await _tripRepository.getTrips(page: nextPage);

      final allTrips = [...state.trips, ...response.trips];
      AppLogger.state('Trips', 'Loaded ${response.trips.length} more trips (total loaded: ${allTrips.length})');
      state = state.copyWith(
        trips: allTrips,
        total: response.total,
        currentPage: nextPage,
        hasMore: allTrips.length < response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load more trips: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create trip
  Future<void> createTrip(TripRequest request) async {
    AppLogger.action('Creating trip: ${request.title}');
    try {
      final newTrip = await _tripRepository.createTrip(request);
      AppLogger.info('Trip created successfully: ${newTrip.title}');
      state = state.copyWith(
        trips: [newTrip, ...state.trips],
        total: state.total + 1,
      );
    } catch (e) {
      AppLogger.error('Failed to create trip: $e');
      rethrow;
    }
  }

  /// Update trip
  Future<void> updateTrip(String id, Map<String, dynamic> updates) async {
    AppLogger.action('Updating trip: $id');
    try {
      final updatedTrip = await _tripRepository.updateTrip(id, updates);
      final updatedTrips = state.trips.map((trip) {
        return trip.id == id ? updatedTrip : trip;
      }).toList();
      AppLogger.info('Trip updated successfully: ${updatedTrip.title}');
      state = state.copyWith(trips: updatedTrips);
    } catch (e) {
      AppLogger.error('Failed to update trip: $e');
      rethrow;
    }
  }

  /// Delete trip
  Future<void> deleteTrip(String id) async {
    AppLogger.action('Deleting trip: $id');
    try {
      await _tripRepository.deleteTrip(id);
      final updatedTrips = state.trips.where((trip) => trip.id != id).toList();
      AppLogger.info('Trip deleted successfully');
      state = state.copyWith(
        trips: updatedTrips,
        total: state.total - 1,
      );
    } catch (e) {
      AppLogger.error('Failed to delete trip: $e');
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
  TripRepository get _tripRepository => ref.read(tripRepositoryProvider);

  @override
  Future<TripModel?> build(String tripId) async {
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
