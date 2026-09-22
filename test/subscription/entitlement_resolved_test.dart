import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/data/repositories/subscription_repository.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';

import 'stub_dio_client.dart';

/// `resolved()`: the wait that anything denying on the absence of Premium has
/// to do before it decides.
///
/// Everything that merely *displays* an upsell can read the entitlement and
/// stay quiet while it is unknown. Something answering a tap cannot stay quiet
/// - it has to allow or refuse - and both readings of `unknown` are wrong:
/// treating it as free bills a subscriber twice, treating it as Premium gives
/// away what has not been bought. So it asks, and waits.
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

void main() {
  late AppDatabase db;
  late StubDioClient dio;

  const statusPath = '/subscription/status';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseService.overrideForTesting(db);
    dio = StubDioClient();
    // The supporting data is not what these are about, but leaving it
    // unstubbed throws inside the same refresh and muddies the result.
    dio.onGet('/subscription/usage', () async => <String, dynamic>{});
    dio.onGet('/subscription/limits', () async => <String, dynamic>{});
    dio.onGet('/subscription/pricing', () async => <String, dynamic>{});
    AccountSession().begin('user-1');
  });

  tearDown(() async {
    AccountSession().end();
    DatabaseService.clearOverrideForTesting();
    await db.close();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(
          SubscriptionRepository(dioClient: dio),
        ),
        analyticsServiceProvider.overrideWithValue(AnalyticsFacade([])),
      ],
    );
    // The notifier starts its own refresh on build. Letting that finish before
    // the container goes keeps its late completion from landing on a disposed
    // provider and failing the test for something it is not about.
    addTearDown(() async {
      await pumpEventQueue();
      c.dispose();
    });
    // Mounted here rather than at the first assertion: the notifier's build()
    // is what starts the initial refresh, and a test that pumps before
    // touching the provider would be pumping an empty queue.
    c.read(subscriptionProvider);
    return c;
  }

  test('a slow server does not make a subscriber look free', () async {
    // Nothing cached, so the entitlement starts unknown - the state every
    // account is in for the first moment after launch.
    final answered = Completer<Map<String, dynamic>>();
    dio.onGet(statusPath, () => answered.future);

    final c = container();
    expect(c.read(entitlementProvider), Entitlement.unknown);

    final waiting = c.read(subscriptionProvider.notifier).resolved();

    // The tap is still waiting, and crucially nothing has decided yet.
    var settled = false;
    unawaited(waiting.then((_) => settled = true));
    await pumpEventQueue();
    expect(
      settled,
      isFalse,
      reason: 'it must not answer before the server does',
    );

    answered.complete(_premium.toJson());
    expect(await waiting, Entitlement.premium);
  });

  test('an answer already in hand is returned without asking again', () async {
    await db.subscriptionCacheDao.setSubscriptionStatus(
      jsonEncode(_free.toJson()),
    );
    dio.onGet(statusPath, () async => _free.toJson());

    final c = container();
    await pumpEventQueue();
    expect(c.read(entitlementProvider), Entitlement.free);

    final before = dio.callsTo(statusPath);
    expect(
      await c.read(subscriptionProvider.notifier).resolved(),
      Entitlement.free,
    );
    expect(
      dio.callsTo(statusPath),
      before,
      reason: 'the answer was already known',
    );
  });

  test('several gated taps share one request', () async {
    final answered = Completer<Map<String, dynamic>>();
    dio.onGet(statusPath, () => answered.future);

    final c = container();
    await pumpEventQueue();
    final before = dio.callsTo(statusPath);

    final notifier = c.read(subscriptionProvider.notifier);
    final all = Future.wait([
      notifier.resolved(),
      notifier.resolved(),
      notifier.resolved(),
    ]);

    await pumpEventQueue();
    answered.complete(_premium.toJson());

    expect(await all, [
      Entitlement.premium,
      Entitlement.premium,
      Entitlement.premium,
    ]);
    expect(
      dio.callsTo(statusPath) - before,
      lessThanOrEqualTo(1),
      reason: 'three taps must not become three requests',
    );
  });

  test('a server that never answers gives back unknown, not free', () async {
    // The whole point. Timing out must not be read as "no subscription" -
    // that is how a paying customer meets a paywall.
    dio.onGet(statusPath, () => Completer<Map<String, dynamic>>().future);

    final c = container();
    final entitlement = await c
        .read(subscriptionProvider.notifier)
        .resolved(timeout: const Duration(milliseconds: 50));

    expect(entitlement, Entitlement.unknown);
    expect(entitlement.isKnownFree, isFalse);
    expect(entitlement.isPremium, isFalse);
  });

  test('signed out, it does not go asking', () async {
    AccountSession().end();
    dio.onGet(statusPath, () async => _premium.toJson());

    final c = container();
    final before = dio.callsTo(statusPath);

    expect(
      await c.read(subscriptionProvider.notifier).resolved(),
      Entitlement.unknown,
    );
    expect(dio.callsTo(statusPath), before);
  });
}
