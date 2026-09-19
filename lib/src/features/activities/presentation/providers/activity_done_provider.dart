import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/storage_service.dart';

part 'activity_done_provider.g.dart';

/// Which activities the user has ticked off.
///
/// Screen 3f of the redesign makes every activity card a tap target that marks
/// the plan done — lime tint, filled check, strike-through. There is no field
/// behind it: `ActivityDto` on the server carries no completion flag, so this
/// keeps the state on the device.
///
/// That means a tick does not sync between devices and does not survive a
/// reinstall. Adding `IsCompleted` to the activity DTO and its migration is
/// what would fix that; until then this is the honest shape of the feature,
/// and it is kept deliberately small so swapping it for a server field later
/// touches this file and the two storage methods behind it.
@Riverpod(keepAlive: true)
class ActivityDone extends _$ActivityDone {
  @override
  Set<String> build(String tripId) {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    state = await StorageService().getDoneActivities(tripId);
  }

  Future<void> toggle(String activityId) async {
    final next = Set<String>.from(state);
    if (!next.remove(activityId)) next.add(activityId);
    state = next;
    await StorageService().setDoneActivities(tripId, next);
  }

  bool isDone(String activityId) => state.contains(activityId);

  /// Drops any ids that no longer exist, so deleting an activity does not
  /// leave its tick behind for a future id to inherit.
  Future<void> prune(Iterable<String> existingIds) async {
    final alive = state.intersection(existingIds.toSet());
    if (alive.length == state.length) return;

    state = alive;
    await StorageService().setDoneActivities(tripId, alive);
  }
}
