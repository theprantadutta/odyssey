import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_service.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/sync/sync_service.dart';
import '../../features/sync/presentation/screens/sync_conflicts_screen.dart';

/// Small sync status icon for use in AppBar actions
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    // Conflicts are counted straight from the database rather than through the
    // sync status, because they outlive a sync run: a conflict detected an hour
    // ago is still unresolved after a later sync succeeds.
    return StreamBuilder<int>(
      stream: DatabaseService()
          .database
          .syncQueueDao
          .watchUnresolvedConflictCount(),
      builder: (context, snapshot) {
        final conflicts = snapshot.data ?? 0;

        return IconButton(
          onPressed: () {
            // A conflict is something only the user can settle, so it takes
            // priority over kicking off another sync that cannot fix it.
            if (conflicts > 0) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SyncConflictsScreen(),
              ));
              return;
            }

            if (!syncStatus.isSyncing) {
              ref.read(syncStatusProvider.notifier).triggerSync();
            }
          },
          tooltip: conflicts > 0
              ? '$conflicts ${conflicts == 1 ? 'change needs' : 'changes need'} '
                  'your attention'
              : _getTooltip(syncStatus),
          icon: conflicts > 0
              ? Badge(
                  label: Text('$conflicts',
                      style: const TextStyle(fontSize: 10)),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  child: Icon(Icons.sync_problem,
                      size: 20, color: Theme.of(context).colorScheme.error),
                )
              : _buildIcon(context, syncStatus),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context, SyncStatusState status) {
    if (status.isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (status.isOffline) {
      return const Icon(Icons.cloud_off, size: 20);
    }

    // Partial failure gets the same attention-seeking icon as an outright error:
    // a cloud-success tick over a stuck queue is the one thing this indicator
    // must never show.
    if (status.needsAttention) {
      return Icon(Icons.sync_problem, size: 20, color: Theme.of(context).colorScheme.error);
    }

    if (status.hasPendingChanges) {
      return Badge(
        label: Text('${status.pendingCount}', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.cloud_upload_outlined, size: 20),
      );
    }

    return Icon(Icons.cloud_done_outlined, size: 20, color: Theme.of(context).colorScheme.primary);
  }

  String _getTooltip(SyncStatusState status) {
    switch (status.syncState) {
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return 'Sync error - tap to retry';
      case SyncState.partialFailure:
        // Truthful: the cycle finished, but the user's own changes did not land.
        return status.hasPendingChanges
            ? '${status.pendingCount} changes need attention - tap to retry'
            : 'Some changes need attention - tap to retry';
      case SyncState.idle:
        if (status.hasPendingChanges) {
          return '${status.pendingCount} pending changes - tap to sync';
        }
        return 'All changes synced';
    }
  }
}
