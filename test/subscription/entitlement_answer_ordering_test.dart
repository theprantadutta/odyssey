import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/core/services/storage_service.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/data/services/purchase_service.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';

/// Whether a *slower* entitlement answer can undo a *newer* one (audit A23).
///
/// Response arrival order is not proof of freshness. A `/subscription/status`
/// read issued before a purchase completed answers `free` truthfully - it is
/// simply answering a question that was asked before the money moved. If that
/// answer is applied because it arrived last, a customer who has just paid is
/// pushed back to Free and shown ads, and the local cache is poisoned so the
/// next launch starts there too.
///
/// These drive the real wiring: the real `PurchaseService` singleton with the
/// `SubscriptionRepository` **it builds for itself**, a second repository built
/// by `subscriptionRepositoryProvider`, a real Drift database and the real
/// providers. Only the HTTP transport is substituted, at the adapter, so
/// `DioClient`, the cache write, the session guard and the publication are all
/// shipping code. Injecting one repository into both roles - which the sibling
/// suite does - would hide whether `PurchaseService` reaches anybody at all.

const _statusPath = '/subscription/status';
const _verifyPath = '/subscription/purchase/verify';

const _premium = SubscriptionStatus(
  tier: SubscriptionTier.premium,
  plan: SubscriptionPlan.monthly,
  isPremium: true,
);

const _free = SubscriptionStatus(
  tier: SubscriptionTier.free,
  plan: SubscriptionPlan.free,
  isPremium: false,
);

/// The receipt `PurchaseService` replays on resume, in the shape
/// `backendPayloadFor` produces.
const _receipt = <String, dynamic>{
  'product_id': 'odyssey_premium_monthly',
  'transaction_id': 'txn-ordering-1',
  'platform': 'android',
  'receipt_data': 'token-ordering-1',
  'purchase_token': 'token-ordering-1',
};

/// Answers Dio from a script, one handler per path, swappable mid-flight.
///
/// Substituted at the adapter rather than at `DioClient` so the request goes
/// through the real client the app uses - including the instance
/// `PurchaseService` resolves for itself.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<String> requested = <String>[];
  final Map<String, Future<Map<String, dynamic>> Function()> _handlers = {};

  void on(String path, Future<Map<String, dynamic>> Function() handler) {
    _handlers[path] = handler;
  }

  int callsTo(String path) => requested.where((p) => p == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.path);

    final handler = _handlers[options.path];
    if (handler == null) {
      // Usage, limits and pricing are not what these tests are about. Failing
      // them also checks they cannot take entitlement down with them.
      return ResponseBody.fromString('{}', 503, headers: _jsonHeaders);
    }

    return ResponseBody.fromString(
      jsonEncode(await handler()),
      200,
      headers: _jsonHeaders,
    );
  }

  static const _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ScriptedAdapter adapter;

  final storage = StorageService();

  setUpAll(() {
    // ApiConfig reads these; dotenv must be loaded before DioClient touches it.
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    DioClient().init();
    // The auth interceptor would try to refresh a token against a server that
    // does not exist. Everything under test - client, repository, provider,
    // PurchaseService - runs unchanged.
    DioClient().dio.interceptors.clear();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseService.overrideForTesting(db);
    adapter = _ScriptedAdapter();
    DioClient().dio.httpClientAdapter = adapter;
    AccountSession().begin('user-1');
  });

  tearDown(() async {
    AccountSession().end();
    DatabaseService.clearOverrideForTesting();
    await db.close();
  });

  Future<void> cache(SubscriptionStatus status) =>
      db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(status.toJson()));

  Future<bool> cachedIsPremium() async {
    final cached = await db.subscriptionCacheDao.getSubscriptionStatus();
    if (cached == null) return false;
    return SubscriptionStatus.fromJson(jsonDecode(cached) as Map<String, dynamic>)
        .isPremium;
  }

  /// A container wired exactly as the app wires it: nothing about the
  /// subscription path is overridden, so `subscriptionRepositoryProvider` builds
  /// its own repository and `PurchaseService` builds a different one.
  ///
  /// Analytics is replaced with a facade that has no clients: the real provider
  /// reaches for Firebase, which is not what is under test here.
  ProviderContainer containerWithEntitlementLog(List<Entitlement> log) {
    final container = ProviderContainer(overrides: [
      analyticsServiceProvider.overrideWithValue(AnalyticsFacade([])),
    ]);
    addTearDown(container.dispose);

    container.listen<Entitlement>(
      entitlementProvider,
      (_, next) => log.add(next),
      fireImmediately: true,
    );

    return container;
  }

  /// Runs the receipt through the real `PurchaseService`, which verifies it with
  /// its own repository instance and refreshes status from there.
  Future<void> confirmPurchase() async {
    await storage.savePendingVerifications([Map<String, dynamic>.of(_receipt)]);
    await PurchaseService().retryPendingVerifications();
    await pumpEventQueue();
  }

  test(
      'a status read issued before the purchase cannot revert Premium to Free',
      () async {
    // The device knows itself to be free, and a status read is already in
    // flight - a resume refresh, say, issued while the billing sheet was open.
    // The server answers it truthfully: at the moment that request was asked,
    // this account had no subscription.
    await cache(_free);
    final readIssuedBeforeThePurchase = Completer<Map<String, dynamic>>();
    adapter.on(_statusPath, () => readIssuedBeforeThePurchase.future);

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);
    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.free,
        reason: 'the cached answer lands first, as it is meant to');
    expect(adapter.callsTo(_statusPath), 1,
        reason: 'exactly one status read is in flight, and it is held');

    // The purchase goes through and the backend confirms it. Everything from
    // here answers premium.
    adapter.on(_verifyPath, () async => {'verified': true});
    adapter.on(_statusPath, () async => _premium.toJson());

    await confirmPurchase();

    expect(container.read(entitlementProvider), Entitlement.premium,
        reason: "PurchaseService's own repository must reach this provider");
    expect(container.read(isKnownFreeProvider), isFalse);

    // What `Purchase._onPurchaseComplete` does next.
    await container.read(subscriptionProvider.notifier).forceRefresh();
    expect(container.read(entitlementProvider), Entitlement.premium);

    // Now the older read finally answers. It is honest and it is stale.
    readIssuedBeforeThePurchase.complete(_free.toJson());
    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.premium,
        reason: 'an answer to a question asked before the purchase cannot '
            'undo the purchase');
    expect(container.read(isKnownFreeProvider), isFalse,
        reason: 'the ad gate must not show ads to a customer who has paid');
    expect(seen.last, Entitlement.premium);

    // The cache decides what the next launch starts from, so a stale answer
    // must not be written there either.
    expect(await cachedIsPremium(), isTrue,
        reason: 'the stale answer must not be cached over the new one');
  });

  test('a purchase confirmed by PurchaseService reaches the ad gate on its own',
      () async {
    // No forceRefresh, no resume, nothing pulling: the only path from the
    // backend's "verified" to the ad gate is PurchaseService's own repository
    // publishing to the one the provider listens to. They are different
    // objects; if the stream were per-instance this would still read free.
    await cache(_free);
    adapter.on(_statusPath, () async => _free.toJson());

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);
    await pumpEventQueue();

    expect(container.read(isKnownFreeProvider), isTrue);

    adapter.on(_verifyPath, () async => {'verified': true});
    adapter.on(_statusPath, () async => _premium.toJson());

    await confirmPurchase();

    expect(container.read(entitlementProvider), Entitlement.premium);
    expect(container.read(isKnownFreeProvider), isFalse);
    expect(await cachedIsPremium(), isTrue);
  });

  test('a status read issued after the purchase is still allowed to lower it',
      () async {
    // The counterpart to the first test, and the reason Premium is not simply
    // pinned: a refund, a chargeback or a cancelled plan has to land. This read
    // is issued after the purchase, so it is genuinely newer and wins.
    await cache(_free);
    adapter.on(_verifyPath, () async => {'verified': true});
    adapter.on(_statusPath, () async => _premium.toJson());

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);
    await pumpEventQueue();

    await confirmPurchase();
    expect(container.read(entitlementProvider), Entitlement.premium);

    // The subscription is revoked server-side; a fresh read is issued now.
    adapter.on(_statusPath, () async => _free.toJson());
    await container.read(subscriptionProvider.notifier).forceRefresh();

    expect(container.read(entitlementProvider), Entitlement.free,
        reason: 'a genuinely newer answer must still be able to lower access');
    expect(container.read(isKnownFreeProvider), isTrue);
    expect(await cachedIsPremium(), isFalse);
  });

  test('a first status read that lands after a sign-out is never applied',
      () async {
    // Nothing cached, so this is the uncached fetch rather than the background
    // refresh. The account changes while it is in flight; the answer belongs to
    // somebody who is no longer signed in.
    final held = Completer<Map<String, dynamic>>();
    adapter.on(_statusPath, () => held.future);

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);
    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.unknown);

    AccountSession().end();

    // From here the stub answers as user-2, because that is what the server
    // would do: a read issued after the switch carries user-2's token. Opening
    // a session prompts one, since an entitlement that never resolved has to be
    // asked for again - without that, an account whose first read is lost has
    // no second chance and sits on unknown forever.
    adapter.on(_statusPath, () async => _free.toJson());
    AccountSession().begin('user-2');

    // ...and only now does user-1's read land. It is the answer under test.
    held.complete(_premium.toJson());
    await pumpEventQueue();

    expect(container.read(entitlementProvider), isNot(Entitlement.premium),
        reason: "user-1's Premium must not be handed to user-2");
    expect(seen, isNot(contains(Entitlement.premium)),
        reason: "user-1's Premium must never have been published at all");

    // Whatever is cached belongs to user-2, so the next launch starts from
    // their entitlement and not from the one that was in flight for user-1.
    final cached = await db.subscriptionCacheDao.getSubscriptionStatus();
    if (cached != null) {
      expect(jsonDecode(cached)['is_premium'], isFalse,
          reason: "user-1's answer must not be what the next launch reads");
    }
  });
}
