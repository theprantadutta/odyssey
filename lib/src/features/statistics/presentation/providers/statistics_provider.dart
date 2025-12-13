import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/statistics_model.dart';
import '../../data/repositories/statistics_repository.dart';

part 'statistics_provider.g.dart';

/// Statistics repository provider
@riverpod
StatisticsRepository statisticsRepository(Ref ref) {
  return StatisticsRepository();
}

/// Overall statistics state
class StatisticsState {
  final OverallStatistics? statistics;
  final bool isLoading;
  final String? error;

  const StatisticsState({
    this.statistics,
    this.isLoading = false,
    this.error,
  });

  StatisticsState copyWith({
    OverallStatistics? statistics,
    bool? isLoading,
    String? error,
  }) {
    return StatisticsState(
      statistics: statistics ?? this.statistics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Statistics provider
@riverpod
class Statistics extends _$Statistics {
  StatisticsRepository get _repository => ref.read(statisticsRepositoryProvider);

  @override
  StatisticsState build() {
    Future.microtask(() => _loadStatistics());
    return const StatisticsState();
  }

  Future<void> _loadStatistics() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final stats = await _repository.getOverallStatistics();
      state = state.copyWith(
        statistics: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await _loadStatistics();
  }
}

/// Year in review state
class YearInReviewState {
  final YearInReviewStats? stats;
  final int selectedYear;
  final bool isLoading;
  final String? error;

  YearInReviewState({
    this.stats,
    int? selectedYear,
    this.isLoading = false,
    this.error,
  }) : selectedYear = selectedYear ?? DateTime.now().year;

  YearInReviewState copyWith({
    YearInReviewStats? stats,
    int? selectedYear,
    bool? isLoading,
    String? error,
  }) {
    return YearInReviewState(
      stats: stats ?? this.stats,
      selectedYear: selectedYear ?? this.selectedYear,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Year in review provider
@riverpod
class YearInReview extends _$YearInReview {
  StatisticsRepository get _repository => ref.read(statisticsRepositoryProvider);

  @override
  YearInReviewState build() {
    Future.microtask(() => _loadYearInReview());
    return YearInReviewState();
  }

  Future<void> _loadYearInReview() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final stats = await _repository.getYearInReview(year: state.selectedYear);
      state = state.copyWith(
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> changeYear(int year) async {
    state = state.copyWith(selectedYear: year);
    await _loadYearInReview();
  }

  Future<void> refresh() async {
    await _loadYearInReview();
  }
}

/// Travel timeline state
class TimelineState {
  final List<TravelTimelineItem> items;
  final int totalTrips;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const TimelineState({
    this.items = const [],
    this.totalTrips = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  TimelineState copyWith({
    List<TravelTimelineItem>? items,
    int? totalTrips,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return TimelineState(
      items: items ?? this.items,
      totalTrips: totalTrips ?? this.totalTrips,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Travel timeline provider
@riverpod
class TravelTimelineNotifier extends _$TravelTimelineNotifier {
  StatisticsRepository get _repository => ref.read(statisticsRepositoryProvider);

  @override
  TimelineState build() {
    Future.microtask(() => _loadTimeline());
    return const TimelineState();
  }

  Future<void> _loadTimeline() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final timeline = await _repository.getTravelTimeline();
      state = state.copyWith(
        items: timeline.items,
        totalTrips: timeline.totalTrips,
        isLoading: false,
        hasMore: timeline.items.length < timeline.totalTrips,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final timeline = await _repository.getTravelTimeline(
        offset: state.items.length,
      );
      state = state.copyWith(
        items: [...state.items, ...timeline.items],
        isLoading: false,
        hasMore: state.items.length + timeline.items.length < timeline.totalTrips,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = const TimelineState();
    await _loadTimeline();
  }
}
