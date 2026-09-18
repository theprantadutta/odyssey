import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/logger_service.dart';

/// A reward the user earned but whose grant has not been seen yet.
class PendingReward {
  const PendingReward({
    required this.feature,
    required this.intentId,
    required this.earnedAt,
  });

  /// The server's feature key.
  final String feature;

  final String intentId;
  final DateTime earnedAt;

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'intent_id': intentId,
        'earned_at': earnedAt.toIso8601String(),
      };

  static PendingReward? fromJson(Map<String, dynamic> json) {
    final feature = json['feature'] as String?;
    final intentId = json['intent_id'] as String?;
    final earnedAt = DateTime.tryParse(json['earned_at'] as String? ?? '');

    if (feature == null || intentId == null || earnedAt == null) return null;
    return PendingReward(
      feature: feature,
      intentId: intentId,
      earnedAt: earnedAt.toUtc(),
    );
  }
}

/// Remembers rewards that were earned but not yet confirmed.
///
/// The reward travels to the server through the ad network, so there is a window
/// where the user has genuinely watched an ad and the grant has not arrived. If
/// the app is closed during that window - or simply gives up waiting - the fact
/// that they earned something must not be lost with it. The user did their part;
/// the delivery is ours to chase.
///
/// Written per account, because a reward belongs to the person who earned it and
/// must not be picked up by whoever signs in next.
class PendingRewardStore {
  // Matches StorageService's configuration, so pending rewards live under the
  // same protection as the tokens they belong beside.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String _key(String userId) => 'pending_rewards_$userId';

  /// How long an unconfirmed reward is worth chasing.
  ///
  /// The unlock itself only lasts a day, so a reward whose confirmation has not
  /// arrived well past that is of no use to anyone and is dropped rather than
  /// retried forever.
  static const Duration retention = Duration(hours: 36);

  Future<List<PendingReward>> load(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      final cutoff = DateTime.now().toUtc().subtract(retention);

      return decoded
          .map((e) => PendingReward.fromJson(e as Map<String, dynamic>))
          .whereType<PendingReward>()
          .where((r) => r.earnedAt.isAfter(cutoff))
          .toList();
    } catch (e) {
      // Corrupt storage must not stop the app reading its entitlements. The
      // worst case is one unconfirmed reward going unchased.
      AppLogger.debug('Could not read pending rewards: $e');
      return const [];
    }
  }

  Future<void> add(String userId, PendingReward reward) async {
    final existing = await load(userId);

    // An intent is single-use, so recording it twice would mean chasing the same
    // reward twice.
    if (existing.any((r) => r.intentId == reward.intentId)) return;

    await _write(userId, [...existing, reward]);
  }

  Future<void> remove(String userId, String intentId) async {
    final remaining =
        (await load(userId)).where((r) => r.intentId != intentId).toList();
    await _write(userId, remaining);
  }

  /// Drops everything for an account - on sign-out, or account deletion.
  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (e) {
      AppLogger.debug('Could not clear pending rewards: $e');
    }
  }

  Future<void> _write(String userId, List<PendingReward> rewards) async {
    try {
      if (rewards.isEmpty) {
        await _storage.delete(key: _key(userId));
        return;
      }

      await _storage.write(
        key: _key(userId),
        value: jsonEncode(rewards.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.debug('Could not save pending rewards: $e');
    }
  }
}
