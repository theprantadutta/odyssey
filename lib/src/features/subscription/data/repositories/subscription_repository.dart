import 'dart:async';
import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../models/subscription_model.dart';
import '../../../../core/session/account_session.dart';

/// Repository for subscription API calls - read-cache pattern
class SubscriptionRepository {
  /// [dioClient] is injectable so a test can drive the real cache-and-publish
  /// path without standing up Dio's interceptor chain.
  SubscriptionRepository({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient();

  final DioClient _dioClient;

  /// Resolved on every use, not captured once: the database is a single file
  /// shared by whichever account is signed in, and a signed-out-and-back-in
  /// session replaces it.
  AppDatabase get _db => DatabaseService().database;

  /// Shared by every instance, deliberately.
  ///
  /// This class is not a singleton, and more than one is built: the provider
  /// creates one and `PurchaseService` creates another. A per-instance
  /// controller meant the purchase path published to an object with no
  /// listeners - so verifying a purchase, the single most important moment for
  /// this stream to fire, reached nobody.
  static final _statusUpdates =
      StreamController<SubscriptionStatusAnswer>.broadcast();

  /// How many `/subscription/status` requests have been *issued*.
  ///
  /// Static for the same reason the controller is: the provider's repository
  /// and `PurchaseService`'s own instance both ask this endpoint, so their
  /// answers have to be ordered against each other and not each against itself.
  static int _statusRequestsIssued = 0;

  /// The issue-order of the newest answer already accepted.
  static int _newestAcceptedStatus = 0;

  /// Claims a place in the answer order, taken at request START.
  ///
  /// WHY the request start and not the response: the order answers come back in
  /// says nothing about which one is fresher. A `/subscription/status` read
  /// issued while the billing sheet was still open answers `free` perfectly
  /// truthfully - it is answering a question asked before the money moved - and
  /// if it is applied merely because it landed last, a customer who has just
  /// paid is pushed back to Free, shown ads, and starts the next launch there
  /// too because the answer was cached on the way past.
  ///
  /// Two alternatives were weighed. Having the server stamp when each status was
  /// computed is the more correct answer and is what would order answers across
  /// devices - but it is a wire change on an endpoint this client cannot deploy
  /// on its own, and it still needs a client-side comparison exactly like this
  /// one. Treating a purchase-confirmed result as a floor fixes only the case
  /// that was reported: it says nothing about two ordinary reads crossing, and
  /// it needs an explicit escape hatch for refunds, cancellations and expiry -
  /// a floor that can be lowered is just this rule with a worse name.
  ///
  /// Issue order is a local, monotonic proxy for freshness that needs nothing
  /// from the server. It is a proxy: see the class doc on
  /// [SubscriptionStatusAnswer] for what it does not cover.
  static int _issueStatusRequest() => ++_statusRequestsIssued;

  /// Whether an answer may be applied, claiming its place if so.
  ///
  /// Claimed synchronously, before the cache write is awaited, so two answers in
  /// flight at once cannot interleave and leave the older one in the database.
  static bool _acceptStatusAnswer(int sequence) {
    if (sequence < _newestAcceptedStatus) {
      AppLogger.info(
          'Dropped subscription status answer $sequence; '
          '$_newestAcceptedStatus is newer');
      return false;
    }

    _newestAcceptedStatus = sequence;
    return true;
  }

  /// Entitlement learned *after* a caller has already been answered.
  ///
  /// [getStatus] hands back the cached status straight away and refreshes behind
  /// it. Without somewhere for that later answer to go, the refresh only ever
  /// reached the database: an account upgraded on another device, or a
  /// subscription that lapsed, stayed at its cached value here until something
  /// happened to read the cache again - which, for the ad gate, meant the next
  /// launch. A subscriber kept seeing ads they had just paid to remove.
  Stream<SubscriptionStatusAnswer> get statusUpdates => _statusUpdates.stream;

  static const String _basePath = '/subscription';

  /// Get current user's subscription status - reads from cache, background refresh
  Future<SubscriptionStatusAnswer> getStatus() async {
    final cached = await _db.subscriptionCacheDao.getSubscriptionStatus();

    if (cached != null) {
      final status = SubscriptionStatus.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshStatus();
      }

      return SubscriptionStatusAnswer.fromCache(status);
    }

    if (!ConnectivityService().isOnline) {
      // Deliberately *not* a fabricated free status.
      //
      // Returning one here was a quiet downgrade: a subscriber who opens the app
      // offline before anything has been cached - a fresh install, or the first
      // launch after signing in - would be told they are on the free plan, and
      // the app would start showing them ads. Entitlement is either known or it
      // is not, and this is the "not" case.
      throw const SubscriptionStatusUnavailable(
        'Subscription status is not available offline yet.',
      );
    }

    return _fetchStatus();
  }

  /// Get current user's usage information - reads from cache, background refresh
  Future<UsageInfo> getUsage() async {
    final cached = await _db.subscriptionCacheDao.getUsageInfo();

    if (cached != null) {
      final usage = UsageInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshUsage();
      }

      return usage;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Usage information is not available offline. Please connect to the internet.';
    }

    return _fetchUsage();
  }

  /// Get subscription limits - reads from cache, background refresh
  Future<SubscriptionLimits> getLimits() async {
    final cached = await _db.subscriptionCacheDao.getLimits();

    if (cached != null) {
      final limits = SubscriptionLimits.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshLimits();
      }

      return limits;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Subscription limits are not available offline. Please connect to the internet.';
    }

    return _fetchLimits();
  }

  /// Get pricing information - API-only with cache fallback
  Future<PricingInfo> getPricing() async {
    final scope = AccountSession().capture();
    if (!ConnectivityService().isOnline) {
      final cached = await _db.subscriptionCacheDao.get('pricing');
      if (cached != null) {
        return PricingInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      throw 'Pricing information requires an internet connection';
    }

    final response = await _dioClient.get('$_basePath/pricing');
    final pricing = PricingInfo.fromJson(response.data);

    // Cache for future offline access
    await scope.write(() => _db.subscriptionCacheDao.set('pricing', jsonEncode(response.data)));

    return pricing;
  }

  /// Check if user can access a specific feature
  Future<bool> canAccessFeature(String featureName) async {
    if (!ConnectivityService().isOnline) {
      // Check cached status
      final cached = await _db.subscriptionCacheDao.getSubscriptionStatus();
      if (cached != null) {
        final status = SubscriptionStatus.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return status.isPremium;
      }
      return false;
    }

    final response = await _dioClient.get('$_basePath/feature/$featureName');
    return response.data['has_access'] as bool;
  }

  /// Check if user has storage space for a file
  Future<StorageCheckResult> checkStorageSpace(int fileSizeBytes) async {
    final response = await _dioClient.get(
      '$_basePath/storage/check',
      queryParameters: {'fileSizeBytes': fileSizeBytes},
    );
    return StorageCheckResult.fromJson(response.data);
  }

  /// Verify and process a purchase with the backend
  /// Sends a receipt to the backend and returns its response body.
  ///
  /// Returns null when the backend could not be reached or answered with an
  /// error status. The caller must treat null as *transient*, never as a
  /// rejection: refusing to deliver a purchase the user really paid for because
  /// our own server was down is the one outcome we cannot take back.
  ///
  /// [payload] is built by `backendPayloadFor` and already carries the keys the
  /// endpoint expects (`product_id`, `receipt_data`, `purchase_token`,
  /// `transaction_id`, `platform`).
  Future<Map<String, dynamic>?> verifyPurchasePayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.post(
        '$_basePath/purchase/verify',
        data: payload,
      );

      final body = response.data;
      if (body is! Map) return null;

      final normalized = Map<String, dynamic>.from(body);
      if (normalized['verified'] as bool? ?? false) {
        // Refresh cached status after purchase
        _refreshStatus();
      }
      return normalized;
    } catch (e) {
      AppLogger.error('Failed to verify purchase: $e');
      return null;
    }
  }

  /// Restore purchases - syncs with backend
  Future<bool> restorePurchases({
    required String platform,
    required List<String> productIds,
  }) async {
    try {
      final response = await _dioClient.post(
        '$_basePath/purchase/restore',
        data: {
          'platform': platform,
          'product_ids': productIds,
        },
      );
      final restored = response.data['restored'] as bool? ?? false;
      if (restored) {
        _refreshStatus();
      }
      return restored;
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      return false;
    }
  }

  /// Force-fetch status from server, bypassing cache. Used after purchase.
  Future<SubscriptionStatusAnswer> getStatusFresh() async {
    return _fetchStatus();
  }

  /// Force-fetch usage from server, bypassing cache.
  Future<UsageInfo> getUsageFresh() async {
    return _fetchUsage();
  }

  /// Force-fetch limits from server, bypassing cache.
  Future<SubscriptionLimits> getLimitsFresh() async {
    return _fetchLimits();
  }

  // --- Private Methods ---

  Future<SubscriptionStatusAnswer> _fetchStatus() async {
    final scope = AccountSession().capture();
    final sequence = _issueStatusRequest();

    final response = await _dioClient.get('$_basePath/status');
    final status = SubscriptionStatus.fromJson(response.data);

    // A stale answer is still handed back, tagged with the sequence that makes
    // it stale, so the caller drops it rather than believing the count of
    // answers it has seen. Only the cache write is skipped here: writing it
    // would decide what the *next* launch starts from.
    if (_acceptStatusAnswer(sequence)) {
      final stored = await scope.write(() =>
          _db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(response.data)));

      // The account changed while this was in flight. The answer describes
      // somebody who is no longer signed in, so it may not be returned either -
      // the caller would apply it to whoever replaced them.
      if (!stored) {
        throw const SubscriptionStatusUnavailable(
          'Subscription status arrived for an account that has signed out.',
        );
      }
    }

    return SubscriptionStatusAnswer(status, sequence);
  }

  Future<void> _refreshStatus() async {
    final scope = AccountSession().capture();
    final sequence = _issueStatusRequest();

    try {
      final response = await _dioClient.get('$_basePath/status');

      // Older than an answer already applied. Not published, and deliberately
      // not cached either: a stale value in the cache is the same downgrade one
      // launch later.
      if (!_acceptStatusAnswer(sequence)) return;

      final stored = await scope.write(
          () => _db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(response.data)));

      // Only publish what was stored. A result the session guard refused belongs
      // to an account that has since signed out, and putting it on the stream
      // would show the previous user's entitlement to the current one.
      if (!stored) return;

      _statusUpdates.add(SubscriptionStatusAnswer(
        SubscriptionStatus.fromJson(response.data),
        sequence,
      ));
    } catch (e) {
      AppLogger.warning('Background subscription status refresh failed: $e');
    }
  }

  Future<UsageInfo> _fetchUsage() async {
    final scope = AccountSession().capture();
    final response = await _dioClient.get('$_basePath/usage');
    final usage = UsageInfo.fromJson(response.data);
    await scope.write(() => _db.subscriptionCacheDao.setUsageInfo(jsonEncode(response.data)));
    return usage;
  }

  Future<void> _refreshUsage() async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get('$_basePath/usage');
      await scope.write(() => _db.subscriptionCacheDao.setUsageInfo(jsonEncode(response.data)));
    } catch (e) {
      AppLogger.warning('Background usage refresh failed: $e');
    }
  }

  Future<SubscriptionLimits> _fetchLimits() async {
    final scope = AccountSession().capture();
    final response = await _dioClient.get('$_basePath/limits');
    final limits = SubscriptionLimits.fromJson(response.data);
    await scope.write(() => _db.subscriptionCacheDao.setLimits(jsonEncode(response.data)));
    return limits;
  }

  Future<void> _refreshLimits() async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get('$_basePath/limits');
      await scope.write(() => _db.subscriptionCacheDao.setLimits(jsonEncode(response.data)));
    } catch (e) {
      AppLogger.warning('Background limits refresh failed: $e');
    }
  }
}

/// An entitlement answer together with where it sits in the answer order.
///
/// [sequence] is the order the request that produced it was **issued**, not the
/// order it came back in. Answers to `/subscription/status` overtake each other
/// routinely - a read issued before a purchase completed can land after the one
/// that confirmed it - and the later arrival is not the fresher fact.
///
/// What this does *not* order:
///   * answers across devices or app launches. The sequence is process-local
///     and resets to zero on restart; only a server-side "computed at" stamp
///     could order those, and the endpoint does not send one.
///   * two requests issued together where the server happened to evaluate the
///     later one first. Issue order is a proxy for computation order, not the
///     same thing; the window is the difference between the two send times.
class SubscriptionStatusAnswer {
  const SubscriptionStatusAnswer(this.status, this.sequence);

  /// An answer read out of the local cache, which has no issue order of its own.
  ///
  /// [unordered] sorts before every real answer, so a cached value can be
  /// applied when nothing better has arrived and is refused once something has.
  const SubscriptionStatusAnswer.fromCache(this.status) : sequence = unordered;

  /// The sequence of an answer that was never a request.
  static const int unordered = 0;

  final SubscriptionStatus status;

  final int sequence;
}

/// Storage check result
class StorageCheckResult {
  final bool hasSpace;
  final int fileSizeBytes;
  final int currentUsedBytes;
  final int limitBytes;
  final int remainingBytes;

  StorageCheckResult({
    required this.hasSpace,
    required this.fileSizeBytes,
    required this.currentUsedBytes,
    required this.limitBytes,
    required this.remainingBytes,
  });

  factory StorageCheckResult.fromJson(Map<String, dynamic> json) {
    return StorageCheckResult(
      hasSpace: json['has_space'] as bool,
      fileSizeBytes: json['file_size_bytes'] as int,
      currentUsedBytes: json['current_used_bytes'] as int,
      limitBytes: json['limit_bytes'] as int,
      remainingBytes: json['remaining_bytes'] as int,
    );
  }
}

/// Thrown when entitlement simply is not knowable right now.
///
/// Distinct from an ordinary failure so callers can tell "we could not find out"
/// from "something went wrong". Neither is a reason to assume the free tier, but
/// only one of them is worth showing the user an error about.
class SubscriptionStatusUnavailable implements Exception {
  const SubscriptionStatusUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
