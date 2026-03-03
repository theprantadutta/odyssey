import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/notification_preference_model.dart';
import '../../data/repositories/notification_preference_repository.dart';

part 'notification_preference_provider.g.dart';

/// Notification preference repository provider
@Riverpod(keepAlive: true)
NotificationPreferenceRepository notificationPreferenceRepository(Ref ref) {
  return NotificationPreferenceRepository();
}

/// Notification preference state
class NotificationPreferenceState {
  final NotificationPreferenceModel? preferences;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const NotificationPreferenceState({
    this.preferences,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  NotificationPreferenceState copyWith({
    NotificationPreferenceModel? preferences,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return NotificationPreferenceState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

/// Notification preferences provider
@Riverpod(keepAlive: true)
class NotificationPreferences extends _$NotificationPreferences {
  NotificationPreferenceRepository get _repository =>
      ref.read(notificationPreferenceRepositoryProvider);

  @override
  NotificationPreferenceState build() {
    return const NotificationPreferenceState();
  }

  /// Load preferences from server
  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final prefs = await _repository.getPreferences();
      state = state.copyWith(preferences: prefs, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        // Use defaults if fetch fails
        preferences: state.preferences ?? const NotificationPreferenceModel(),
      );
    }
  }

  /// Update a preference and sync to server
  Future<bool> updatePreferences(NotificationPreferenceModel updated) async {
    final previousPrefs = state.preferences;

    // Optimistic update
    state = state.copyWith(preferences: updated, isSaving: true, error: null);

    try {
      final saved = await _repository.updatePreferences(updated);
      state = state.copyWith(preferences: saved, isSaving: false);
      return true;
    } catch (e) {
      // Rollback
      state = state.copyWith(
        preferences: previousPrefs,
        isSaving: false,
        error: e.toString(),
      );
      return false;
    }
  }
}
