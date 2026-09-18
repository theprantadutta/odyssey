import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../ads/presentation/providers/ads_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/feature_grant_repository.dart';
import 'subscription_provider.dart';
import 'unlock_resolution.dart';

part 'feature_access_provider.g.dart';

/// How long a rewarded-ad "watch to unlock" grant lasts.
///
/// The server decides the real expiry and sends it back; this is only what the
/// offer promises the user before they watch. The two must agree
/// (`FeatureGrantService.GrantDuration`), or the button will advertise a length
/// the grant does not have.
const Duration kTemporaryUnlockDuration = Duration(hours: 24);

/// Premium-gated features that a free user can temporarily unlock by watching a
/// rewarded ad.
///
/// [storageKey] is the stable persistence key — never rename, or every unlock
/// already on a device is orphaned. [serverKey] is the name the server's
/// entitlement check knows the feature by; it is separate because the two
/// vocabularies were not identical and forcing them together would have meant
/// renaming one of the persistence keys.
enum PremiumFeature {
  worldMap('world_map', 'world_map', 'World Map'),
  fullStatistics('full_statistics', 'full_statistics', 'Full Statistics'),
  videoUpload('video_upload', 'video', 'Video Uploads'),
  editSharing('edit_sharing', 'edit_sharing', 'Edit Collaboration'),
  yearInReview('year_in_review', 'year_in_review', 'Year in Review');

  const PremiumFeature(this.storageKey, this.serverKey, this.displayName);

  final String storageKey;
  final String serverKey;
  final String displayName;

  static PremiumFeature? fromServerKey(String key) {
    for (final feature in PremiumFeature.values) {
      if (feature.serverKey == key) return feature;
    }
    return null;
  }
}

/// The currently-valid temporary unlocks (feature → expiry).
///
/// **The server is the authority.** The unlock is granted server-side when the ad
/// network confirms the reward, and the same entitlement decision answers the
/// request the user makes once they are through the gate. This map is a cache of
/// that answer, persisted so the gate still works offline and across restarts.
///
/// It used to be the other way round: the device wrote its own 24-hour expiry and
/// the server knew nothing about it, so a user could finish an ad, pass the gate,
/// and be refused by the server on the very next request.
@Riverpod(keepAlive: true)
class TemporaryUnlocks extends _$TemporaryUnlocks {
  final StorageService _storage = StorageService();
  final FeatureGrantRepository _repository = FeatureGrantRepository();

  Timer? _expiryTimer;

  @override
  Map<PremiumFeature, DateTime> build() {
    ref.onDispose(() => _expiryTimer?.cancel());

    unawaited(_restore());
    return const {};
  }

  /// Loads the cached answer, then asks the server for the current one.
  Future<void> _restore() async {
    final restored = <PremiumFeature, DateTime>{};
    final now = DateTime.now().toUtc();

    for (final feature in PremiumFeature.values) {
      final expiry = await _storage.getFeatureUnlockExpiry(feature.storageKey);
      if (expiry != null && expiry.isAfter(now)) {
        restored[feature] = expiry;
      }
    }

    if (restored.isNotEmpty) _apply(restored);

    // The cache can only ever be stale or generous - a grant revoked server-side
    // would still read as live here - so it is corrected as soon as the network
    // allows.
    unawaited(refresh());
  }

  /// Replaces the cached unlocks with the server's current answer.
  ///
  /// Silent on failure: this runs on resume and after sign-in, where a network
  /// error is ordinary and the cached answer is the right thing to keep using.
  Future<void> refresh() async {
    try {
      final grants = await _repository.fetchGrants();
      await _applyFromServer(grants);
    } catch (e) {
      AppLogger.debug('Could not refresh feature grants: $e');
    }
  }

  Future<void> _applyFromServer(FeatureGrants grants) async {
    final next = resolveUnlocks(grants);

    // Written through so the gate survives a restart with no network.
    for (final feature in PremiumFeature.values) {
      final expiry = next[feature];
      if (expiry != null) {
        await _storage.saveFeatureUnlockExpiry(feature.storageKey, expiry);
      } else {
        await _storage.clearFeatureUnlock(feature.storageKey);
      }
    }

    _apply(next);
  }

  /// Records an unlock the server has confirmed.
  Future<void> applyGrants(FeatureGrants grants) => _applyFromServer(grants);

  /// Refreshes, and also chases any reward earned but not yet confirmed.
  ///
  /// The reward reaches the server through the ad network, so a user can close
  /// the app between earning one and its arrival. That is not their problem to
  /// solve by watching another ad.
  Future<void> refreshIncludingPending() async {
    final userId = ref.read(authProvider).user?.id;

    if (userId == null) {
      await refresh();
      return;
    }

    try {
      final grants =
          await ref.read(rewardOfferControllerProvider).resolvePending(userId);

      // resolvePending only fetches when something is outstanding, so a null
      // answer means "nothing pending", not "nothing granted".
      if (grants != null) {
        await _applyFromServer(grants);
        return;
      }
    } catch (e) {
      AppLogger.debug('Could not resolve pending rewards: $e');
    }

    await refresh();
  }

  void _apply(Map<PremiumFeature, DateTime> unlocks) {
    state = unlocks;
    _scheduleNextExpiry();
  }

  /// Rebuilds the gates the moment the earliest unlock runs out.
  ///
  /// Without this, `isUnlocked` only becomes false the next time something
  /// happens to re-read it: a screen already built stays unlocked indefinitely,
  /// because nothing tells Riverpod that time passing changed the answer.
  void _scheduleNextExpiry() {
    _expiryTimer?.cancel();

    final soonest = nextExpiry(state);
    if (soonest == null) return;

    final remaining = soonest.difference(DateTime.now().toUtc());

    if (remaining.isNegative) {
      _dropExpired();
      return;
    }

    _expiryTimer = Timer(remaining + const Duration(seconds: 1), _dropExpired);
  }

  void _dropExpired() {
    final live = dropExpired(state, DateTime.now().toUtc());

    if (live.length != state.length) {
      _apply(live);
    } else {
      _scheduleNextExpiry();
    }
  }

  /// Whether [feature] is currently unlocked via a non-expired grant.
  bool isUnlocked(PremiumFeature feature) {
    final expiry = state[feature];
    return expiry != null && expiry.isAfter(DateTime.now().toUtc());
  }

  /// How long is left on [feature]'s unlock, or null if it is not unlocked.
  Duration? remainingFor(PremiumFeature feature) {
    final expiry = state[feature];
    if (expiry == null) return null;

    final remaining = expiry.difference(DateTime.now().toUtc());
    return remaining.isNegative ? null : remaining;
  }
}

/// THE gate every premium feature should read: true if the user is premium OR
/// has a valid temporary unlock for [feature]. Replaces bare `isPremiumProvider`
/// checks at feature gates so rewarded unlocks actually take effect.
///
/// It answers the same question the server answers, from the server's own grant.
/// Being let in here and refused there is the failure this exists to prevent.
@Riverpod(keepAlive: true)
bool featureAccess(Ref ref, PremiumFeature feature) {
  if (ref.watch(isPremiumProvider)) return true;
  final unlocks = ref.watch(temporaryUnlocksProvider);
  final expiry = unlocks[feature];
  return expiry != null && expiry.isAfter(DateTime.now().toUtc());
}

/// How long is left on a temporary unlock, or null when there isn't one.
///
/// Separate from [featureAccess] so a screen can say "3 hours left" without
/// every gate rebuilding when the number changes.
@Riverpod(keepAlive: true)
Duration? unlockRemaining(Ref ref, PremiumFeature feature) {
  final unlocks = ref.watch(temporaryUnlocksProvider);
  final expiry = unlocks[feature];
  if (expiry == null) return null;

  final remaining = expiry.difference(DateTime.now().toUtc());
  return remaining.isNegative ? null : remaining;
}
