import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/storage_service.dart';
import 'subscription_provider.dart';

part 'feature_access_provider.g.dart';

/// How long a rewarded-ad "watch to unlock" grant lasts.
const Duration kTemporaryUnlockDuration = Duration(hours: 24);

/// Premium-gated features that a free user can temporarily unlock by watching a
/// rewarded ad. The [storageKey] is the stable persistence key — never rename.
enum PremiumFeature {
  worldMap('world_map', 'World Map'),
  fullStatistics('full_statistics', 'Full Statistics'),
  videoUpload('video_upload', 'Video Uploads'),
  editSharing('edit_sharing', 'Edit Collaboration'),
  yearInReview('year_in_review', 'Year in Review');

  const PremiumFeature(this.storageKey, this.displayName);

  final String storageKey;
  final String displayName;
}

/// Holds the currently-valid temporary unlocks (feature → expiry). Persisted via
/// [StorageService] so unlocks survive app restarts for [kTemporaryUnlockDuration].
///
/// Restored on first build; expired entries are dropped. Reads are synchronous
/// off the in-memory map so feature gates can use it in `build()`.
@Riverpod(keepAlive: true)
class TemporaryUnlocks extends _$TemporaryUnlocks {
  final StorageService _storage = StorageService();

  @override
  Map<PremiumFeature, DateTime> build() {
    unawaited(_restore());
    return const {};
  }

  Future<void> _restore() async {
    final restored = <PremiumFeature, DateTime>{};
    final now = DateTime.now();
    for (final feature in PremiumFeature.values) {
      final expiry = await _storage.getFeatureUnlockExpiry(feature.storageKey);
      if (expiry != null && expiry.isAfter(now)) {
        restored[feature] = expiry;
      }
    }
    if (restored.isNotEmpty) state = restored;
  }

  /// Grant (or extend) access to [feature] for [kTemporaryUnlockDuration].
  Future<void> unlock(PremiumFeature feature) async {
    final expiry = DateTime.now().add(kTemporaryUnlockDuration);
    await _storage.saveFeatureUnlockExpiry(feature.storageKey, expiry);
    state = {...state, feature: expiry};
  }

  /// Whether [feature] is currently unlocked via a non-expired grant.
  bool isUnlocked(PremiumFeature feature) {
    final expiry = state[feature];
    return expiry != null && expiry.isAfter(DateTime.now());
  }
}

/// THE gate every premium feature should read: true if the user is premium OR
/// has a valid temporary unlock for [feature]. Replaces bare `isPremiumProvider`
/// checks at feature gates so rewarded unlocks actually take effect.
@Riverpod(keepAlive: true)
bool featureAccess(Ref ref, PremiumFeature feature) {
  if (ref.watch(isPremiumProvider)) return true;
  final unlocks = ref.watch(temporaryUnlocksProvider);
  final expiry = unlocks[feature];
  return expiry != null && expiry.isAfter(DateTime.now());
}
