import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/trip_filter_model.dart';
import '../../data/repositories/trip_repository.dart';

part 'trips_provider.g.dart';

/// Trips state with filter support
class TripsState {
  final List<TripModel> trips;
  final bool isLoading;
  final String? error;
  final int total;
  final int currentPage;
  final bool hasMore;
  final TripFilterModel filters;
  final List<String> availableTags;

  const TripsState({
    this.trips = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.filters = const TripFilterModel(),
    this.availableTags = const [],
  });

  TripsState copyWith({
    List<TripModel>? trips,
    bool? isLoading,
    String? error,
    int? total,
    int? currentPage,
    bool? hasMore,
    TripFilterModel? filters,
    List<String>? availableTags,
  }) {
    return TripsState(
      trips: trips ?? this.trips,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      filters: filters ?? this.filters,
      availableTags: availableTags ?? this.availableTags,
    );
  }
}

/// Trip repository provider
@riverpod
TripRepository tripRepository(Ref ref) {
  return TripRepository();
}

/// Trips list provider with search and filter support
@riverpod
class Trips extends _$Trips {
  TripRepository get _tripRepository => ref.read(tripRepositoryProvider);

  @override
  TripsState build() {
    Future.microtask(() => _loadTrips());
    return const TripsState();
  }

  /// Load trips (first page) with current filters
  Future<void> _loadTrips() async {
    final filters = state.filters;
    final hasFilters = filters.hasActiveFilters || filters.hasCustomSorting;

    AppLogger.state('Trips', 'Loading trips (page 1)${hasFilters ? ' with filters' : ''}');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _tripRepository.getTrips(
        page: 1,
        filters: hasFilters ? filters : null,
      );

      AppLogger.state('Trips', 'Loaded ${response.trips.length} trips (total: ${response.total})');

      state = state.copyWith(
        trips: response.trips,
        total: response.total,
        currentPage: 1,
        hasMore: response.trips.length < response.total,
        isLoading: false,
      );

      // Load available tags in background
      _loadAvailableTags();
    } catch (e) {
      AppLogger.error('Failed to load trips: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load available tags for filter UI
  Future<void> _loadAvailableTags() async {
    try {
      final tags = await _tripRepository.getAvailableTags();
      state = state.copyWith(availableTags: tags);
    } catch (e) {
      AppLogger.warning('Failed to load available tags: $e');
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
    final filters = state.filters;
    final hasFilters = filters.hasActiveFilters || filters.hasCustomSorting;

    AppLogger.state('Trips', 'Loading more trips (page $nextPage)');
    state = state.copyWith(isLoading: true);

    try {
      final response = await _tripRepository.getTrips(
        page: nextPage,
        filters: hasFilters ? filters : null,
      );

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

  /// Update filters and reload trips
  Future<void> updateFilters(TripFilterModel filters) async {
    AppLogger.action('Updating trip filters');
    state = state.copyWith(filters: filters);
    await _loadTrips();
  }

  /// Search trips by title
  Future<void> search(String? query) async {
    final newFilters = state.filters.copyWith(
      search: query,
      clearSearch: query == null || query.isEmpty,
    );
    await updateFilters(newFilters);
  }

  /// Filter by status
  Future<void> filterByStatus(List<String>? statuses) async {
    final newFilters = state.filters.copyWith(
      status: statuses,
      clearStatus: statuses == null || statuses.isEmpty,
    );
    await updateFilters(newFilters);
  }

  /// Filter by tags
  Future<void> filterByTags(List<String>? tags) async {
    final newFilters = state.filters.copyWith(
      tags: tags,
      clearTags: tags == null || tags.isEmpty,
    );
    await updateFilters(newFilters);
  }

  /// Filter by date range
  Future<void> filterByDateRange(DateTime? from, DateTime? to) async {
    final newFilters = state.filters.copyWith(
      startDateFrom: from,
      startDateTo: to,
      clearStartDateFrom: from == null,
      clearStartDateTo: to == null,
    );
    await updateFilters(newFilters);
  }

  /// Update sorting
  Future<void> updateSorting(TripSortField sortBy, TripSortOrder sortOrder) async {
    final newFilters = state.filters.copyWith(
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    await updateFilters(newFilters);
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    AppLogger.action('Clearing all trip filters');
    await updateFilters(const TripFilterModel());
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
      // Reload available tags
      _loadAvailableTags();
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
      // Reload available tags in case tags changed
      _loadAvailableTags();
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
      // Reload available tags
      _loadAvailableTags();
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
