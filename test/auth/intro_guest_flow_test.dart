import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/router/app_router.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:odyssey/src/features/auth/presentation/screens/intro_screen.dart';
import 'package:odyssey/src/features/auth/presentation/screens/legal_agreement_screen.dart';

/// Auth with the storage and database left out: each step only moves state,
/// which is all the router reads.
class _FakeAuth extends Auth {
  _FakeAuth(this._initial);

  final AuthState _initial;
  final guestSources = <String>[];

  @override
  AuthState build() => _initial;

  @override
  Future<void> setIntroSeen() async =>
      state = state.copyWith(hasSeenIntro: true);

  @override
  Future<void> setTermsAccepted() async =>
      state = state.copyWith(hasAcceptedTerms: true);

  @override
  Future<void> continueAsGuest({required String source}) async {
    guestSources.add(source);
    state = state.copyWith(
      isGuest: true,
      isAuthenticated: false,
      needsOnboarding: true,
    );
  }
}

class _RecordingAnalytics implements AnalyticsFacade {
  int introShown = 0;
  final slides = <int>[];
  final choices = <String>[];

  @override
  Future<void> trackIntroShown() async => introShown++;

  @override
  Future<void> trackIntroSlideViewed({required int slide}) async =>
      slides.add(slide);

  @override
  Future<void> trackIntroChoice({required String choice}) async =>
      choices.add(choice);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// A first-time user is offered the app without an account as the main way
/// in from the intro. The choice survives the legal gate, the guest warning is
/// shown once the terms are agreed, and the gates run on to onboarding.
void main() {
  late _FakeAuth auth;
  late _RecordingAnalytics analytics;
  late GoRouter router;

  /// A fresh install: intro not seen, terms not accepted, nobody signed in.
  const freshInstall = AuthState(hasSeenIntro: false, hasAcceptedTerms: false);

  setUp(() {
    // The intro's choices live for one run; do not let a test inherit one.
    takePendingGuestStart();
  });

  /// pumpAndSettle cannot be used: the legal screen shows a shimmering
  /// skeleton until its documents load, which is real I/O that fake time
  /// never finishes. So the I/O is given real time, then the frames run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      for (var j = 0; j < 6; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> pumpIntro(WidgetTester tester, AuthState initial) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    auth = _FakeAuth(initial);
    analytics = _RecordingAnalytics();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(container.dispose);

    final refresh = ValueNotifier<int>(0);
    addTearDown(refresh.dispose);
    container.listen(authProvider, (_, _) => refresh.value++);

    Widget placeholder(String name) => Scaffold(body: Text('$name screen'));
    router = GoRouter(
      initialLocation: AppRoutes.intro,
      refreshListenable: refresh,
      redirect: (context, state) => resolveAuthRedirect(
        container.read(authProvider),
        state.matchedLocation,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.intro,
          builder: (context, state) => const IntroScreen(),
        ),
        GoRoute(
          path: AppRoutes.legalAgreement,
          builder: (context, state) => const LegalAgreementScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => placeholder('login'),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => placeholder('register'),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => placeholder('onboarding'),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => placeholder('home'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<void> toLastSlide(WidgetTester tester) async {
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');
  }

  Future<void> agreeToTerms(WidgetTester tester) async {
    expect(find.text('Before we\nbegin.'), findsOneWidget);
    await tapText(
      tester,
      'I have read and agree to the Terms and the Privacy Policy.',
    );
    await tapText(tester, 'Continue');
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('Start planning goes through the terms and the guest warning '
      'to onboarding as a guest', (tester) async {
    await pumpIntro(tester, freshInstall);
    expect(analytics.introShown, 1);

    await toLastSlide(tester);
    expect(find.text('Start planning'), findsOneWidget);
    expect(find.text('No account needed'), findsOneWidget);
    expect(analytics.slides, [1, 2]);

    await tapText(tester, 'Start planning');
    expect(location(), AppRoutes.legalAgreement);
    expect(analytics.choices, ['guest']);
    // Nothing is asked before the terms.
    expect(find.text('Use Odyssey without an account?'), findsNothing);

    await agreeToTerms(tester);
    expect(find.text('Use Odyssey without an account?'), findsOneWidget);

    await tapText(tester, 'Continue without an account');
    expect(auth.guestSources, ['intro']);
    expect(auth.state.hasAcceptedTerms, isTrue);
    expect(location(), AppRoutes.onboarding);
  });

  testWidgets('Skip takes the same guest path', (tester) async {
    await pumpIntro(tester, freshInstall);

    await tapText(tester, 'Skip');
    expect(location(), AppRoutes.legalAgreement);
    expect(analytics.choices, ['skip']);

    await agreeToTerms(tester);
    await tapText(tester, 'Continue without an account');
    expect(auth.guestSources, ['intro']);
    expect(location(), AppRoutes.onboarding);
  });

  testWidgets('turning the warning down still accepts the terms and lands on '
      'sign-in', (tester) async {
    await pumpIntro(tester, freshInstall);
    await toLastSlide(tester);
    await tapText(tester, 'Start planning');
    await agreeToTerms(tester);

    await tapText(tester, 'Back');
    expect(auth.guestSources, isEmpty);
    expect(auth.state.isGuest, isFalse);
    expect(auth.state.hasAcceptedTerms, isTrue);
    expect(location(), AppRoutes.login);
  });

  testWidgets('Create account still reaches the register screen, with no '
      'guest warning', (tester) async {
    await pumpIntro(tester, freshInstall);

    await tapText(tester, 'Create account');
    expect(location(), AppRoutes.legalAgreement);
    expect(analytics.choices, ['register']);

    await agreeToTerms(tester);
    expect(find.text('Use Odyssey without an account?'), findsNothing);
    expect(auth.guestSources, isEmpty);
    expect(location(), AppRoutes.register);
  });

  testWidgets('I already have an account still reaches sign-in',
      (tester) async {
    await pumpIntro(tester, freshInstall);

    await tapText(tester, 'I already have an account');
    expect(analytics.choices, ['login']);

    await agreeToTerms(tester);
    expect(auth.guestSources, isEmpty);
    expect(location(), AppRoutes.login);
  });

  testWidgets('a reinstall still signed in through the Keychain is never made '
      'a guest', (tester) async {
    await pumpIntro(
      tester,
      const AuthState(
        isAuthenticated: true,
        hasSeenIntro: false,
        hasAcceptedTerms: false,
      ),
    );

    await toLastSlide(tester);
    await tapText(tester, 'Start planning');
    expect(location(), AppRoutes.legalAgreement);

    await agreeToTerms(tester);
    expect(find.text('Use Odyssey without an account?'), findsNothing);
    expect(auth.guestSources, isEmpty);
    expect(location(), AppRoutes.home);
  });

  testWidgets('with the terms already accepted, the warning is shown on the '
      'intro itself', (tester) async {
    await pumpIntro(
      tester,
      const AuthState(hasSeenIntro: false, hasAcceptedTerms: true),
    );

    await tapText(tester, 'Skip');
    expect(find.text('Use Odyssey without an account?'), findsOneWidget);

    await tapText(tester, 'Continue without an account');
    expect(auth.guestSources, ['intro']);
    expect(location(), AppRoutes.onboarding);
  });
}
