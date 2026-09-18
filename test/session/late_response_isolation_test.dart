import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/features/trips/data/repositories/trip_repository.dart';

/// What happens to a response that arrives after its account has signed out.
///
/// The local database is a single file shared by whoever is signed in, and
/// repositories resolve it freshly on every use. A request started by account A
/// and answered after account B signs in therefore writes A's private rows into
/// B's database - the account generation existed, but no repository consulted
/// it, so nothing stopped the write.
///
/// These drive the real repository against a real temporary database. Only the
/// HTTP transport is substituted, so the response can be held open across the
/// account switch, which is the whole point.
class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

/// A request captured in flight, completed by the test when it chooses.
class _Pending {
  _Pending(this.options);

  final RequestOptions options;
  final Completer<ResponseBody> response = Completer<ResponseBody>();

  void complete(Map<String, dynamic> body, {int status = 200}) {
    response.complete(ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    ));
  }
}

class _HeldAdapter implements HttpClientAdapter {
  final List<_Pending> requests = <_Pending>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final pending = _Pending(options);
    requests.add(pending);
    return pending.response.future;
  }

  @override
  void close({bool force = false}) {}

  Future<_Pending> request(int index) async {
    for (var i = 0; i < 500 && requests.length <= index; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return requests[index];
  }
}

Map<String, dynamic> _tripJson(String title) => {
      'id': 'trip',
      'user_id': 'account-a',
      'title': title,
      'start_date': '2026-09-01',
      'end_date': '2026-09-02',
      'status': 'planned',
      'tags': <String>[],
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
      'display_currency': 'USD',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeldAdapter adapter;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    final dir = await Directory.systemTemp.createTemp('odyssey-session-');
    PathProviderPlatform.instance = _Paths(dir.path);
    await DatabaseService().initialize();
    DioClient().init();
    // The auth interceptor would try to refresh a token against a server that
    // does not exist. Everything being tested - repository, session, DAOs -
    // runs unchanged.
    DioClient().dio.interceptors.clear();
  });

  setUp(() async {
    await DatabaseService().database.clearAllData();
    adapter = _HeldAdapter();
    DioClient().dio.httpClientAdapter = adapter;
    AccountSession().end();
    AccountSession().begin('account-a');
  });

  tearDownAll(() async {
    await DatabaseService().close();
  });

  test('a response arriving after sign-out is not written to the next account',
      () async {
    // Account A asks for a trip. The request is held open.
    final operation = TripRepository().getTripById('trip');
    final request = await adapter.request(0);

    // A signs out, the database is cleared, B signs in. All of this happens
    // while A's request is still outstanding - cancelling providers does not
    // cancel a future that is already running.
    AccountSession().end();
    await DatabaseService().clearAllData();
    AccountSession().begin('account-b');

    // Now A's answer arrives.
    request.complete(_tripJson('Account A private title'));

    try {
      await operation;
    } catch (_) {
      // The caller belongs to a session that no longer exists; whether it sees
      // a value or an error is immaterial. What matters is the database.
    }

    expect(AccountSession().userId, 'account-b');

    final row = await DatabaseService().database.tripsDao.getById('trip');
    expect(row, isNull,
        reason: "account A's trip was written into account B's database");
  });

  test('a background refresh answered after sign-out writes nothing', () async {
    final db = DatabaseService().database;

    // A local row, so getTrips returns from the database and kicks off the
    // background refresh rather than fetching inline.
    final repository = TripRepository();
    final seeding = repository.getTripById('trip');
    (await adapter.request(0)).complete(_tripJson('Original'));
    await seeding;

    expect((await db.tripsDao.getById('trip'))!.title, 'Original');

    // A background refresh starts under A...
    unawaited(repository.getTrips());
    final refresh = await adapter.request(1);

    AccountSession().end();
    await DatabaseService().clearAllData();
    AccountSession().begin('account-b');

    // ...and answers under B.
    refresh.complete({
      'trips': [_tripJson('Account A private title')],
      'total': 1,
      'page': 1,
      'page_size': 20,
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await db.tripsDao.getById('trip'), isNull,
        reason: "a background refresh repopulated account B's database");
  });

  test('the same account signing back in is still a different session',
      () async {
    // Signing out and back in as the same person clears the database in
    // between, so work spanning that boundary is just as stale.
    final operation = TripRepository().getTripById('trip');
    final request = await adapter.request(0);

    AccountSession().end();
    await DatabaseService().clearAllData();
    AccountSession().begin('account-a');

    request.complete(_tripJson('From the previous session'));

    try {
      await operation;
    } catch (_) {}

    expect(await DatabaseService().database.tripsDao.getById('trip'), isNull);
  });

  test('a response arriving while the session is unchanged is written',
      () async {
    // The control. A guard that refused everything would pass the tests above
    // and break the application.
    final operation = TripRepository().getTripById('trip');
    (await adapter.request(0)).complete(_tripJson('Kyoto'));
    await operation;

    final row = await DatabaseService().database.tripsDao.getById('trip');
    expect(row, isNotNull);
    expect(row!.title, 'Kyoto');
  });
}
