import '../../data/repositories/feature_grant_repository.dart';
import 'feature_access_provider.dart';

/// Turns the server's grant list into the unlocks this build understands.
///
/// Pure, and separate from the provider, so the rules can be tested without a
/// network, a database or a Riverpod container — the decisions here are the ones
/// that get a user into a feature, and they are worth stating as cases.
Map<PremiumFeature, DateTime> resolveUnlocks(FeatureGrants grants) {
  final resolved = <PremiumFeature, DateTime>{};

  for (final grant in grants.grants) {
    final feature = PremiumFeature.fromServerKey(grant.feature);

    // A feature this build does not know about is ignored rather than treated as
    // an error: an older app talking to a newer server is a normal state, and
    // there is nothing useful it could do with an unlock it cannot render.
    if (feature == null) continue;

    // Measured against the server's clock, not the device's. A device an hour
    // fast would otherwise discard a grant the server still honours - and a
    // device an hour slow would keep one it does not.
    if (!grant.expiresAt.isAfter(grants.serverTime)) continue;

    // The longest wins. Watching a second ad before the first unlock runs out
    // should never shorten it.
    final existing = resolved[feature];
    if (existing == null || grant.expiresAt.isAfter(existing)) {
      resolved[feature] = grant.expiresAt;
    }
  }

  return resolved;
}

/// Drops the unlocks that have run out, as of [now].
Map<PremiumFeature, DateTime> dropExpired(
  Map<PremiumFeature, DateTime> unlocks,
  DateTime now,
) {
  return {
    for (final entry in unlocks.entries)
      if (entry.value.isAfter(now)) entry.key: entry.value
  };
}

/// When the next unlock runs out, or null if none are held.
///
/// The gate has to be rebuilt at that moment. Without it, a screen already built
/// stays unlocked indefinitely: nothing tells Riverpod that time passing changed
/// the answer.
DateTime? nextExpiry(Map<PremiumFeature, DateTime> unlocks) {
  if (unlocks.isEmpty) return null;
  return unlocks.values.reduce((a, b) => a.isBefore(b) ? a : b);
}
