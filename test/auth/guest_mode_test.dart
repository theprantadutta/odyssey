import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/core/network/dio_interceptors.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/router/app_router.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/features/auth/presentation/guest_prompts.dart';
import 'package:odyssey/src/features/auth/presentation/providers/auth_provider.dart';

class _FakeAuth extends Auth {
  _FakeAuth(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _RecordingAnalytics implements AnalyticsFacade {
  final prompts = <String>[];

  @override
  Future<void> trackAccountPromptShown({required String feature}) async =>
      prompts.add(feature);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// A guest uses the app with no account: nothing that needs the server is
/// attempted, and every such feature offers an account instead.
void main() {
  group('requireAccount', () {
    late _RecordingAnalytics analytics;
    late GoRouter router;
    bool? allowed;

    Future<void> pumpWith(WidgetTester tester, AuthState auth) async {
      analytics = _RecordingAnalytics();
      allowed = null;
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async {
                  allowed = await requireAccount(
                    context,
                    ref,
                    feature: 'photo_upload',
                    reason: 'Photos are stored with your account.',
                  );
                },
                child: const Text('add photo'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.register,
            builder: (context, state) => const Text('register screen'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuth(auth)),
            analyticsServiceProvider.overrideWithValue(analytics),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
    }

    testWidgets('lets a signed-in user straight through', (tester) async {
      await pumpWith(tester, const AuthState(isAuthenticated: true));

      await tester.tap(find.text('add photo'));
      await tester.pumpAndSettle();

      expect(allowed, isTrue);
      expect(find.text('Create a free account'), findsNothing);
      expect(analytics.prompts, isEmpty);
    });

    testWidgets('stops a guest and says why', (tester) async {
      await pumpWith(tester, const AuthState(isGuest: true));

      await tester.tap(find.text('add photo'));
      await tester.pumpAndSettle();

      expect(find.text('Create a free account'), findsOneWidget);
      expect(find.text('Photos are stored with your account.'), findsOneWidget);
      expect(analytics.prompts, ['photo_upload']);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(allowed, isFalse);
      expect(find.text('add photo'), findsOneWidget);
    });

    testWidgets('takes a guest who accepts to the register screen, with a '
        'way back', (tester) async {
      await pumpWith(tester, const AuthState(isGuest: true));

      await tester.tap(find.text('add photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(allowed, isFalse);
      expect(find.text('register screen'), findsOneWidget);
      expect(router.canPop(), isTrue);
    });
  });

  group('AuthInterceptor in guest mode', () {
    late Dio dio;
    late List<String> sent;

    setUp(() {
      sent = [];
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(AuthInterceptor())
        ..httpClientAdapter = _RecordingAdapter(sent);
    });

    test('blocks an account request before it is sent', () async {
      FlutterSecureStorage.setMockInitialValues({'guest_mode': 'true'});

      await expectLater(
        dio.get<void>('/trips'),
        throwsA(isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        )),
      );
      expect(sent, isEmpty);
    });

    test('still lets a guest reach the sign-in endpoints', () async {
      FlutterSecureStorage.setMockInitialValues({'guest_mode': 'true'});

      await dio.post<void>('/auth/register');

      expect(sent, ['/auth/register']);
    });

    test('leaves signed-out, non-guest requests alone', () async {
      FlutterSecureStorage.setMockInitialValues({});

      await dio.get<void>('/currency/rates');

      expect(sent, ['/currency/rates']);
    });
  });
}

/// Records each request that actually reaches the network and answers 200.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.sent);

  final List<String> sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options.path);
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}
