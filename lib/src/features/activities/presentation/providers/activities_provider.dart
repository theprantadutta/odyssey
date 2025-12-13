import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';

part 'activities_provider.g.dart';

/// Activities state for a specific trip
class ActivitiesState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final String? error;
  final int total;

  const ActivitiesState({
    this.activities = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  ActivitiesState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return ActivitiesState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// Activity repository provider
@riverpod
ActivityRepository activityRepository(Ref ref) {
  return ActivityRepository();
}

/// Activities list provider for a specific trip
@riverpod
class TripActivities extends _$TripActivities {
  ActivityRepository get _activityRepository =>
      ref.read(activityRepositoryProvider);

  @override
  ActivitiesState build(String tripId) {
    Future.microtask(() => _loadActivities());
    return const ActivitiesState(isLoading: true);
  }

  /// Load activities for the trip
  Future<void> _loadActivities() async {
    AppLogger.state('Activities', 'Loading activities for trip: $tripId');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _activityRepository.getActivities(tripId: tripId);

      AppLogger.state(
          'Activities', 'Loaded ${response.activities.length} activities');

      state = state.copyWith(
        activities: response.activities,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Failed to load activities: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh activities
  Future<void> refresh() async {
    await _loadActivities();
  }

  /// Create activity
  Future<void> createActivity(ActivityRequest request) async {
    AppLogger.action('Creating activity: ${request.title}');
    try {
      final newActivity = await _activityRepository.createActivity(request);
      AppLogger.info('Activity created successfully: ${newActivity.title}');

      // Add to list and sort by sort_order
      final updatedActivities = [...state.activities, newActivity];
      updatedActivities.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      state = state.copyWith(
        activities: updatedActivities,
        total: state.total + 1,
      );
    } catch (e) {
      AppLogger.error('Failed to create activity: $e');
      rethrow;
    }
  }

  /// Update activity
  Future<void> updateActivity(String id, Map<String, dynamic> updates) async {
    AppLogger.action('Updating activity: $id');
    try {
      final updatedActivity =
          await _activityRepository.updateActivity(id, updates);
      final updatedActivities = state.activities.map((activity) {
        return activity.id == id ? updatedActivity : activity;
      }).toList();
      AppLogger.info('Activity updated successfully: ${updatedActivity.title}');
      state = state.copyWith(activities: updatedActivities);
    } catch (e) {
      AppLogger.error('Failed to update activity: $e');
      rethrow;
    }
  }

  /// Delete activity
  Future<void> deleteActivity(String id) async {
    AppLogger.action('Deleting activity: $id');
    try {
      await _activityRepository.deleteActivity(id);
      final updatedActivities =
          state.activities.where((activity) => activity.id != id).toList();
      AppLogger.info('Activity deleted successfully');
      state = state.copyWith(
        activities: updatedActivities,
        total: state.total - 1,
      );
    } catch (e) {
      AppLogger.error('Failed to delete activity: $e');
      rethrow;
    }
  }

  /// Reorder activities (for drag-and-drop)
  Future<void> reorderActivities(int oldIndex, int newIndex) async {
    AppLogger.action('Reordering activities: $oldIndex -> $newIndex');

    // Optimistically update the UI
    final activities = List<ActivityModel>.from(state.activities);
    final activity = activities.removeAt(oldIndex);
    activities.insert(newIndex, activity);

    // Update sort orders
    final activityOrders = <ActivityOrder>[];
    for (var i = 0; i < activities.length; i++) {
      activityOrders.add(ActivityOrder(
        id: activities[i].id,
        sortOrder: i,
      ));
    }

    // Update state immediately for smooth UI
    state = state.copyWith(activities: activities);

    try {
      await _activityRepository.reorderActivities(
        tripId: tripId,
        activityOrders: activityOrders,
      );
      AppLogger.info('Activities reordered successfully');
      // Refresh to get updated sort orders from server
      await refresh();
    } catch (e) {
      AppLogger.error('Failed to reorder activities: $e');
      // Revert on failure
      await refresh();
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Single activity provider (for detail/edit view)
@riverpod
class Activity extends _$Activity {
  ActivityRepository get _activityRepository =>
      ref.read(activityRepositoryProvider);

  @override
  Future<ActivityModel?> build(String activityId) async {
    return await _loadActivity(activityId);
  }

  Future<ActivityModel?> _loadActivity(String activityId) async {
    try {
      return await _activityRepository.getActivityById(activityId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh single activity
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadActivity(activityId));
  }
}
