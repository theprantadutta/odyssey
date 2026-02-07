import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/sync_provider.dart';
import '../../core/sync/sync_service.dart';

/// Small sync status icon for use in AppBar actions
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return IconButton(
      onPressed: () {
        if (!syncStatus.isSyncing) {
          ref.read(syncStatusProvider.notifier).triggerSync();
        }
      },
      tooltip: _getTooltip(syncStatus),
      icon: _buildIcon(context, syncStatus),
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

    if (status.hasError) {
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
      case SyncState.idle:
        if (status.hasPendingChanges) {
          return '${status.pendingCount} pending changes - tap to sync';
        }
        return 'All changes synced';
    }
  }
}
