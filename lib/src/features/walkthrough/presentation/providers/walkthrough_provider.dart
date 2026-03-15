import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/walkthrough_step_model.dart';

part 'walkthrough_provider.g.dart';

/// State for the walkthrough system
class WalkthroughState {
  final bool isActive;
  final int currentStepIndex;
  final List<WalkthroughStep> steps;
  final String? activeSegmentId;

  const WalkthroughState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.steps = const [],
    this.activeSegmentId,
  });

  WalkthroughState copyWith({
    bool? isActive,
    int? currentStepIndex,
    List<WalkthroughStep>? steps,
    String? activeSegmentId,
  }) {
    return WalkthroughState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      steps: steps ?? this.steps,
      activeSegmentId: activeSegmentId ?? this.activeSegmentId,
    );
  }
}

@Riverpod(keepAlive: true)
class Walkthrough extends _$Walkthrough {
  @override
  WalkthroughState build() => const WalkthroughState();

  /// Called from each screen's initState via addPostFrameCallback.
  /// Starts the walkthrough if the segment hasn't been completed yet.
  Future<void> startIfNeeded(
    String segmentId,
    List<WalkthroughStep> steps,
  ) async {
    // Don't start if already active
    if (state.isActive) return;

    final storage = StorageService();
    final completed = await _isSegmentCompleted(storage, segmentId);
    if (completed) return;

    state = WalkthroughState(
      isActive: true,
      currentStepIndex: 0,
      steps: steps,
      activeSegmentId: segmentId,
    );
  }

  /// Advance to the next step, or complete if on the last step
  void next() {
    if (!state.isActive) return;
    if (state.currentStepIndex < state.steps.length - 1) {
      state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
    } else {
      complete();
    }
  }

  /// Go back to the previous step
  void previous() {
    if (!state.isActive || state.currentStepIndex <= 0) return;
    state = state.copyWith(currentStepIndex: state.currentStepIndex - 1);
  }

  /// Skip the current walkthrough segment entirely
  void skip() {
    if (!state.isActive) return;
    _markCompleted();
  }

  /// Complete the current walkthrough segment
  void complete() {
    if (!state.isActive) return;
    _markCompleted();
  }

  /// Reset all walkthroughs (called from Settings > Replay Walkthrough)
  Future<void> resetAll() async {
    final storage = StorageService();
    await storage.resetAllWalkthroughs();
    state = const WalkthroughState();
  }

  Future<void> _markCompleted() async {
    final segmentId = state.activeSegmentId;
    if (segmentId == null) return;

    final storage = StorageService();
    await _setSegmentCompleted(storage, segmentId);

    state = const WalkthroughState();
  }

  Future<bool> _isSegmentCompleted(
    StorageService storage,
    String segmentId,
  ) async {
    switch (segmentId) {
      case 'dashboard':
        return storage.isDashboardWalkthroughCompleted();
      case 'trip_detail':
        return storage.isTripDetailWalkthroughCompleted();
      case 'trip_creation':
        return storage.isTripCreationWalkthroughCompleted();
      default:
        return false;
    }
  }

  Future<void> _setSegmentCompleted(
    StorageService storage,
    String segmentId,
  ) async {
    switch (segmentId) {
      case 'dashboard':
        await storage.setDashboardWalkthroughCompleted(true);
        break;
      case 'trip_detail':
        await storage.setTripDetailWalkthroughCompleted(true);
        break;
      case 'trip_creation':
        await storage.setTripCreationWalkthroughCompleted(true);
        break;
    }
  }
}
