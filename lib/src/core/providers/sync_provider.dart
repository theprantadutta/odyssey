import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../sync/sync_service.dart';
import '../sync/sync_queue_service.dart';

part 'sync_provider.g.dart';

/// Sync status state
class SyncStatusState {
  final SyncState syncState;
  final int pendingCount;

  const SyncStatusState({
    this.syncState = SyncState.idle,
    this.pendingCount = 0,
  });

  SyncStatusState copyWith({
    SyncState? syncState,
    int? pendingCount,
  }) {
    return SyncStatusState(
      syncState: syncState ?? this.syncState,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  bool get isSyncing => syncState == SyncState.syncing;
  bool get isOffline => syncState == SyncState.offline;
  bool get hasError => syncState == SyncState.error;
  bool get hasPendingChanges => pendingCount > 0;
}

/// Sync status provider - watches sync state and pending changes
@Riverpod(keepAlive: true)
class SyncStatus extends _$SyncStatus {
  StreamSubscription<SyncState>? _syncSubscription;
  StreamSubscription<int>? _pendingSubscription;

  @override
  SyncStatusState build() {
    _syncSubscription?.cancel();
    _syncSubscription = SyncService().stateStream.listen((syncState) {
      state = state.copyWith(syncState: syncState);
    });

    _pendingSubscription?.cancel();
    _pendingSubscription = SyncQueueService().watchPendingCount().listen((count) {
      state = state.copyWith(pendingCount: count);
    });

    ref.onDispose(() {
      _syncSubscription?.cancel();
      _pendingSubscription?.cancel();
    });

    return SyncStatusState(
      syncState: SyncService().currentState,
    );
  }

  /// Manually trigger a sync
  Future<void> triggerSync() async {
    await SyncService().performSync();
  }
}
