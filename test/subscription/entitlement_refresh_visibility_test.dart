import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/data/repositories/subscription_repository.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';

/// Whether a subscription bought, or lost, somewhere else reaches the ad gate
/// (audit A23).
///
/// `getStatus` answers from the cache and refreshes behind it. The refresh wrote
/// the newer status into the database and stopped there - nothing was watching
/// that row - so the entitlement the ad gate reads kept its cached value until
/// something happened to read the cache again. In practice that was the next
/// launch: a subscriber who upgraded on another device carried on being shown
/// ads, and a lapsed subscription carried on being honoured.
///
/// These drive the real repository against a real Drift database and the real
/// provider. Only the HTTP transport is substituted, so the cache write, the
/// session guard on it, and the publication to the provider are all the shipping
/// code.

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

/// A `DioClient` that answers from a script instead of the network.
class _StubDioClient implements DioClient {
  final List<String> requested = <String>[];
  final Map<String, Future<Map<String, dynamic>> Function()> _handlers = {};

  void onGet(String path, Future<Map<String, dynamic>> Function() handler) {
    _handlers[path] = handler;
  }

  int callsTo(String path) => requested.where((p) => p == path).length;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requested.add(path);

    final handler = _handlers[path];
    if (handler == null) {
      // Usage, limits and pricing are not what these tests are about. Failing
      // them also checks they cannot take entitlement down with them.
      throw StateError('no stubbed response for $path');
    }

    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: await handler(),
    );
  }

  @override
  Dio get dio => throw UnimplementedError();

  @override
  void init() => throw UnimplementedError();

  @override
  Future<Response> post(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> put(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> patch(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> delete(String path,
          {dynamic data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response> multipart(String path, FormData formData,
          {Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress}) =>
      throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late _StubDioClient dio;

  const statusPath = '/subscription/status';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    DatabaseService.overrideForTesting(db);
    dio = _StubDioClient();
    AccountSession().begin('user-1');
  });

  tearDown(() async {
    AccountSession().end();
    DatabaseService.clearOverrideForTesting();
    await db.close();
  });

  Future<void> cache(SubscriptionStatus status) =>
      db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(status.toJson()));

  /// A container wired to the real repository over the stubbed transport.
  ///
  /// Analytics is replaced with a facade that has no clients: the real provider
  /// reaches for Firebase, which is not what is under test here.
  ProviderContainer containerWithEntitlementLog(List<Entitlement> log) {
    final container = ProviderContainer(overrides: [
      subscriptionRepositoryProvider
          .overrideWithValue(SubscriptionRepository(dioClient: dio)),
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

  test(
      'an upgrade bought elsewhere reaches the ad gate without a second refresh',
      () async {
    // What this device last knew, and what the server will say when the
    // background refresh that getStatus starts finally answers.
    await cache(_free);
    final answered = Completer<Map<String, dynamic>>();
    dio.onGet(statusPath, () => answered.future);

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();

    // The cached answer arrives first, as it is meant to, and the ad gate acts
    // on it.
    expect(container.read(entitlementProvider), Entitlement.free);
    expect(container.read(isKnownFreeProvider), isTrue);

    // Now the server answers the refresh already in flight. Nobody calls
    // refresh() again; nothing restarts.
    answered.complete(_premium.toJson());
    await pumpEventQueue();

    expect(dio.callsTo(statusPath), 1,
        reason: 'the one background refresh is all that happened');

    expect(container.read(entitlementProvider), Entitlement.premium);
    expect(container.read(isKnownFreeProvider), isFalse,
        reason: 'the ad gate must stop showing ads to a subscriber');

    expect(seen, [Entitlement.unknown, Entitlement.free, Entitlement.premium]);
  });

  test('a lapsed subscription stops being honoured without a restart',
      () async {
    await cache(_premium);
    final answered = Completer<Map<String, dynamic>>();
    dio.onGet(statusPath, () => answered.future);

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();
    expect(container.read(entitlementProvider), Entitlement.premium);

    answered.complete(_free.toJson());
    await pumpEventQueue();

    expect(dio.callsTo(statusPath), 1);
    expect(container.read(entitlementProvider), Entitlement.free);
    expect(container.read(isKnownFreeProvider), isTrue);
    expect(seen, [Entitlement.unknown, Entitlement.premium, Entitlement.free]);
  });

  test('a background answer is not overwritten by the slower cached read',
      () async {
    // The refresh can finish before the cached read it was started by returns.
    // Its answer came from the server, so it is the newer one and has to win;
    // applying the cache afterwards would put the stale entitlement back.
    await cache(_free);
    dio.onGet(statusPath, () async => _premium.toJson());

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.premium);
    expect(seen.last, Entitlement.premium);
    expect(container.read(subscriptionProvider).isLoading, isFalse);
  });

  test('control: an unchanged cached account stays where it was', () async {
    await cache(_free);
    dio.onGet(statusPath, () async => _free.toJson());

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.free);
    expect(container.read(isKnownFreeProvider), isTrue);
    expect(container.read(subscriptionProvider).isLoading, isFalse);

    // Premium never appeared; the refresh did not invent an entitlement.
    expect(seen, isNot(contains(Entitlement.premium)));

    // The cache carries the server's answer for the next launch.
    expect(await db.subscriptionCacheDao.getSubscriptionStatus(), isNotNull);
  });

  test('control: with nothing cached and no answer, entitlement stays unknown',
      () async {
    // No cache row, and the status request fails. There is nothing to know.
    dio.onGet(statusPath, () async => throw StateError('server unreachable'));

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();

    expect(container.read(entitlementProvider), Entitlement.unknown);
    expect(container.read(isKnownFreeProvider), isFalse,
        reason: 'unknown is never shown as free');
    expect(seen, everyElement(Entitlement.unknown));
  });

  test('a refresh that lands after the account changed is not published',
      () async {
    await cache(_free);

    final answered = Completer<Map<String, dynamic>>();
    dio.onGet(statusPath, () => answered.future);

    final seen = <Entitlement>[];
    final container = containerWithEntitlementLog(seen);

    await pumpEventQueue();
    expect(container.read(entitlementProvider), Entitlement.free);

    // The previous account signs out and another signs in while the refresh is
    // still in flight.
    AccountSession().end();
    AccountSession().begin('user-2');

    answered.complete(_premium.toJson());
    await pumpEventQueue();

    // user-1's Premium must not be handed to user-2, and must not be cached
    // under them either.
    expect(container.read(entitlementProvider), Entitlement.free);
    expect(seen, isNot(contains(Entitlement.premium)));

    final cached = await db.subscriptionCacheDao.getSubscriptionStatus();
    expect(
      SubscriptionStatus.fromJson(jsonDecode(cached!) as Map<String, dynamic>)
          .isPremium,
      isFalse,
    );
  });
}
