import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/logger_service.dart';

/// One temporary feature unlock, as the server reports it.
class FeatureGrant {
  const FeatureGrant({required this.feature, required this.expiresAt});

  /// The server's feature key - matches `PremiumFeature.serverKey`.
  final String feature;

  final DateTime expiresAt;
}

/// The server's answer about which features are temporarily unlocked.
class FeatureGrants {
  const FeatureGrants({required this.grants, required this.serverTime});

  final List<FeatureGrant> grants;

  /// The server's clock when it answered.
  ///
  /// Remaining time is measured against this rather than the device clock, which
  /// the user can set. A device an hour fast would otherwise show an unlock as
  /// expired while the server still honours it - and, worse, the reverse.
  final DateTime serverTime;
}

/// An offer the server made before any ad was shown.
///
/// The [intentId] is the only thing that travels with the ad. The account, the
/// feature and the ad unit stay on the server, so nothing the device puts in the
/// reward callback can change what is granted.
class RewardOffer {
  const RewardOffer({
    required this.intentId,
    required this.feature,
    required this.expiresAt,
  });

  final String intentId;
  final String feature;
  final DateTime expiresAt;
}

/// Why the server would not make an offer.
enum OfferRefusal {
  /// This deployment cannot deliver rewards at all - server-side verification
  /// is not configured. The app must stop offering them.
  notConfigured,

  /// The caller can already use the feature.
  alreadyEntitled,

  /// Too many offers outstanding, or the feature is not rewardable.
  refused,

  /// Network or server trouble. Worth another try.
  unavailable,
}

class OfferResult {
  const OfferResult.granted(this.offer) : refusal = null;
  const OfferResult.refused(this.refusal) : offer = null;

  final RewardOffer? offer;
  final OfferRefusal? refusal;

  bool get isSuccess => offer != null;
}

/// Reads temporary feature unlocks from the server, and asks for offers.
///
/// The unlock is granted server-side, in response to the ad network confirming
/// the reward directly. The device never asserts one: it asks what it has.
class FeatureGrantRepository {
  final DioClient _dioClient = DioClient();

  /// Whether this deployment can deliver rewards at all.
  ///
  /// Read before any offer is shown. Null means the question could not be
  /// answered, which is not the same as "no" - the caller keeps whatever it knew.
  Future<bool?> fetchFulfilmentConfigured() async {
    try {
      final response = await _dioClient.get('${ApiConfig.rewards}/availability');
      final data = response.data as Map<String, dynamic>;
      return data['fulfilment_configured'] as bool?;
    } on DioException catch (e) {
      AppLogger.debug('Could not read reward availability: ${e.message}');
      return null;
    }
  }

  /// Asks the server to record what this user is being offered.
  ///
  /// Must happen before the ad is shown. The reward callback carries the returned
  /// intent id and nothing else of consequence, so an offer that was never made
  /// cannot be redeemed.
  Future<OfferResult> createOffer({
    required String feature,
    required String adUnitId,
  }) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.rewards}/offers',
        data: {'feature': feature, 'adUnitId': adUnitId},
      );

      final data = response.data as Map<String, dynamic>;

      if (data['already_entitled'] == true) {
        return const OfferResult.refused(OfferRefusal.alreadyEntitled);
      }

      final intentId = data['intent_id'] as String?;
      final expiry = DateTime.tryParse(data['expires_at'] as String? ?? '');

      if (intentId == null || expiry == null) {
        return const OfferResult.refused(OfferRefusal.unavailable);
      }

      return OfferResult.granted(RewardOffer(
        intentId: intentId,
        feature: data['feature'] as String? ?? feature,
        expiresAt: expiry.toUtc(),
      ));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = e.response?.data is Map<String, dynamic>
          ? (e.response!.data as Map<String, dynamic>)['code'] as String?
          : null;

      if (status == 503 || code == 'NOT_CONFIGURED') {
        return const OfferResult.refused(OfferRefusal.notConfigured);
      }

      if (status == 400 || status == 429) {
        return const OfferResult.refused(OfferRefusal.refused);
      }

      AppLogger.debug('Could not create a reward offer: ${e.message}');
      return const OfferResult.refused(OfferRefusal.unavailable);
    }
  }

  Future<FeatureGrants> fetchGrants() async {
    final response = await _dioClient.get('${ApiConfig.rewards}/grants');
    final data = response.data as Map<String, dynamic>;

    final grants = <FeatureGrant>[];
    for (final entry in (data['grants'] as List<dynamic>? ?? const [])) {
      final row = entry as Map<String, dynamic>;
      final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
      final feature = row['feature'] as String?;
      if (expiry == null || feature == null) continue;
      grants.add(FeatureGrant(feature: feature, expiresAt: expiry.toUtc()));
    }

    final serverTime =
        DateTime.tryParse(data['server_time'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc();

    return FeatureGrants(grants: grants, serverTime: serverTime);
  }

  /// Waits for a grant to appear, for the moment just after an ad completes.
  ///
  /// The reward reaches the server through the ad network, not through this app,
  /// so it does not exist the instant the ad closes. Without this the user would
  /// watch an ad, find the feature still locked, and reasonably conclude it did
  /// not work - so the wait is short, bounded, and failing it is not an error.
  ///
  /// Returns null when the grant has not arrived within [timeout]. The caller is
  /// expected to have recorded the attempt so it can be resolved later, rather
  /// than waiting here indefinitely.
  Future<FeatureGrants?> awaitGrant(
    String feature, {
    Duration timeout = const Duration(seconds: 12),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final grants = await fetchGrants();
        final arrived = grants.grants.any(
          (g) => g.feature == feature && g.expiresAt.isAfter(grants.serverTime),
        );
        if (arrived) return grants;
      } on DioException catch (e) {
        // Offline, or the server is unwell. Either way the grant may still land;
        // the next fetch on resume will pick it up.
        AppLogger.debug('Could not read feature grants: ${e.message}');
        return null;
      }

      await Future<void>.delayed(interval);
    }

    return null;
  }
}
