import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/subscription/data/repositories/feature_grant_repository.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/feature_access_provider.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/unlock_resolution.dart';

/// The rules that decide whether an earned unlock lets a user into a feature.
///
/// The unlock used to be written by the device: a local 24-hour expiry the server
/// knew nothing about, so a user could finish an ad, pass the gate, and be refused
/// by the server on the very next request. These rules turn the server's answer
/// into the device's, which is the direction it has to run.
void main() {
  final serverNow = DateTime.utc(2026, 9, 16, 12, 0);

  FeatureGrants grantsOf(List<FeatureGrant> grants, {DateTime? at}) =>
      FeatureGrants(grants: grants, serverTime: at ?? serverNow);

  group('resolving the server\'s grants', () {
    test('a live grant unlocks its feature', () {
      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.add(const Duration(hours: 20)),
        ),
      ]));

      expect(resolved[PremiumFeature.worldMap],
          serverNow.add(const Duration(hours: 20)));
    });

    test('a grant unlocks only the feature it names', () {
      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.add(const Duration(hours: 20)),
        ),
      ]));

      // A reward is not a tier change. Every other feature stays locked.
      expect(resolved.keys, [PremiumFeature.worldMap]);
    });

    test('the server key is what matches, not the storage key', () {
      // These two differ for video: the persistence key predates the server and
      // renaming it would orphan every unlock already on a device.
      expect(PremiumFeature.videoUpload.storageKey, 'video_upload');
      expect(PremiumFeature.videoUpload.serverKey, 'video');

      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'video',
          expiresAt: serverNow.add(const Duration(hours: 5)),
        ),
      ]));

      expect(resolved.containsKey(PremiumFeature.videoUpload), isTrue);
    });

    test('an already-expired grant unlocks nothing', () {
      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.subtract(const Duration(minutes: 1)),
        ),
      ]));

      expect(resolved, isEmpty);
    });

    test('expiry is judged against the server clock, not the device', () {
      // The device's clock is not consulted at all here: the server said what
      // time it was when it answered. A device an hour fast would otherwise throw
      // away a grant the server still honours.
      final resolved = resolveUnlocks(grantsOf(
        [
          FeatureGrant(
            feature: 'world_map',
            expiresAt: DateTime.utc(2026, 9, 16, 13, 0),
          ),
        ],
        at: DateTime.utc(2026, 9, 16, 12, 30),
      ));

      expect(resolved.containsKey(PremiumFeature.worldMap), isTrue);
    });

    test('a feature this build does not know about is ignored', () {
      // An older app talking to a newer server. There is nothing useful it could
      // do with an unlock it cannot render, and refusing the whole response would
      // lose the grants it does understand.
      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'time_travel',
          expiresAt: serverNow.add(const Duration(hours: 5)),
        ),
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.add(const Duration(hours: 5)),
        ),
      ]));

      expect(resolved.keys, [PremiumFeature.worldMap]);
    });

    test('two grants for one feature keep the longer', () {
      // A second ad watched before the first unlock ran out must never shorten
      // it.
      final resolved = resolveUnlocks(grantsOf([
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.add(const Duration(hours: 20)),
        ),
        FeatureGrant(
          feature: 'world_map',
          expiresAt: serverNow.add(const Duration(hours: 3)),
        ),
      ]));

      expect(resolved[PremiumFeature.worldMap],
          serverNow.add(const Duration(hours: 20)));
    });

    test('an empty answer unlocks nothing', () {
      // What a user with no grants gets - and what the device must then cache,
      // so a stale local unlock cannot outlive the grant it was a copy of.
      expect(resolveUnlocks(grantsOf([])), isEmpty);
    });
  });

  group('expiry', () {
    test('an unlock is dropped once its time is up', () {
      final unlocks = {
        PremiumFeature.worldMap: serverNow.add(const Duration(hours: 1)),
        PremiumFeature.fullStatistics: serverNow.subtract(const Duration(hours: 1)),
      };

      expect(dropExpired(unlocks, serverNow).keys, [PremiumFeature.worldMap]);
    });

    test('an unlock expiring exactly now is dropped', () {
      final unlocks = {PremiumFeature.worldMap: serverNow};
      expect(dropExpired(unlocks, serverNow), isEmpty);
    });

    test('the next expiry is the soonest one', () {
      // What the refresh timer is set to. Scheduling for the latest would leave
      // an expired feature open for hours.
      final unlocks = {
        PremiumFeature.worldMap: serverNow.add(const Duration(hours: 20)),
        PremiumFeature.yearInReview: serverNow.add(const Duration(hours: 2)),
        PremiumFeature.videoUpload: serverNow.add(const Duration(hours: 9)),
      };

      expect(nextExpiry(unlocks), serverNow.add(const Duration(hours: 2)));
    });

    test('no unlocks means nothing to schedule', () {
      expect(nextExpiry(const {}), isNull);
    });
  });

  group('the offer and the grant agree', () {
    test('every rewardable feature has a distinct server key', () {
      final keys = PremiumFeature.values.map((f) => f.serverKey).toList();

      // Two features sharing a server key would mean one reward silently
      // unlocking the other.
      expect(keys.toSet().length, keys.length);
    });

    test('every feature has a distinct storage key', () {
      final keys = PremiumFeature.values.map((f) => f.storageKey).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('the advertised unlock length matches what the server grants', () {
      // The button says "watch an ad to unlock for 24 hours". If the server's
      // FeatureGrantService.GrantDuration ever differs, the offer is a lie - so
      // this is pinned on both sides.
      expect(kTemporaryUnlockDuration, const Duration(hours: 24));
    });
  });
}
