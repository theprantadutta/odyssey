import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../network/authenticated_media_fetch.dart';
import '../utils/authenticated_media.dart';
import '../database/database_service.dart';
import '../services/logger_service.dart';
import '../../features/ads/application/pending_reward_store.dart';
import '../services/storage_service.dart';
import '../sync/sync_service.dart';
import 'account_session.dart';
import 'unsynced_work_quarantine.dart';

/// Tears down everything that belongs to one account, in an order that cannot
/// leave the next account looking at the previous one's data.
///
/// Every way a session can end - signing out, deleting the account, the server
/// rejecting an expired token - has to go through here. Before, only deliberate
/// logout cleared the database: an expired session cleared the auth tokens and
/// left the previous user's trips, entitlements and temporary unlocks in place,
/// so the next person to sign in on that device inherited them.
class AccountStateReset {
  AccountStateReset._();
  static final AccountStateReset _instance = AccountStateReset._();
  factory AccountStateReset() => _instance;

  /// Ends the current session and clears its local state.
  ///
  /// [preserveUnsyncedWork] sets queued work aside under the account that made
  /// it, so signing back in recovers it. It is false for account deletion, where
  /// there is nothing left to sync it to.
  Future<void> reset({
    required String? userId,
    bool preserveUnsyncedWork = true,
  }) async {
    AppLogger.info('Resetting account-scoped state');

    // 1. Close the session first. Anything still running is now writing on
    //    behalf of a session that no longer exists and will be discarded.
    AccountSession().end();

    // 2. Wait for in-flight sync. Clearing the database underneath a running
    //    cycle would either fail or let it write rows back in afterwards.
    await SyncService().stopSession();

    // 3. Set unsynced work aside before the tables are emptied.
    if (preserveUnsyncedWork && userId != null) {
      try {
        // Preserves the operations *and* the rows they act on, so a restored
        // partial edit still has a record to apply to.
        await UnsyncedWorkQuarantine(DatabaseService().database)
            .quarantine(userId);
      } catch (e) {
        AppLogger.error('Failed to quarantine unsynced work: $e');
      }
    }

    // 4. Clear cached rows. The quarantine is preserved by clearAllData.
    try {
      await DatabaseService().clearAllData();
    } catch (e) {
      AppLogger.error('Failed to clear local database: $e');
    }

    // 5. Clear entitlement-adjacent state that is not in the database.
    //    A temporary unlock is granted to a person, not to a device.
    try {
      await StorageService().clearFeatureUnlocks();
    } catch (e) {
      AppLogger.error('Failed to clear feature unlocks: $e');
    }

    // A reward earned but not yet confirmed belongs to the account that earned
    // it. Left behind, the next person to sign in on this device would have it
    // chased - and granted - on their behalf.
    if (userId != null) {
      try {
        await PendingRewardStore().clear(userId);
      } catch (e) {
        AppLogger.error('Failed to clear pending rewards: $e');
      }
    }

    // 6. Drop the media cache and the token that fetches media.
    //    Cached photos, covers and PDFs are private content sitting in a
    //    device-wide cache: left behind, the next account to sign in on this
    //    device could open the previous one's documents straight from disk.
    AuthenticatedMedia.clear();
    try {
      await DefaultCacheManager().emptyCache();
      // Private media has its own manager - and therefore its own cache
      // directory - so that its fetches can refresh an expired token. Emptying
      // only the default one would leave the previous account's photos and
      // documents on disk.
      await AuthenticatedMediaCacheManager.emptyCache();
    } catch (e) {
      AppLogger.error('Failed to clear the media cache: $e');
    }
  }

  /// Opens a session for [userId] and restores any work it left behind.
  Future<void> beginSession(String userId) async {
    AccountSession().begin(userId);

    // Media widgets build synchronously and cannot await secure storage, so the
    // token they send is prepared up front.
    await AuthenticatedMedia.refresh();

    try {
      await UnsyncedWorkQuarantine(DatabaseService().database).restore(userId);
    } catch (e) {
      AppLogger.error('Failed to restore quarantined work: $e');
    }

    await SyncService().startSession();
  }
}
