import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/router/app_router.dart';
import '../guest_prompts.dart';
import '../providers/auth_provider.dart';

/// One slide of the intro.
class _IntroSlide {
  const _IntroSlide({
    required this.headline,
    required this.body,
    required this.image,
  });

  /// Set very large and tight, and deliberately broken across two lines.
  final String headline;

  final String body;

  /// The photograph behind the pitch. See assets/intro/CREDITS.md.
  final String image;
}

/// Onboarding — screen 3a.
///
/// A 520px full-bleed photo that dissolves into the canvas, then the pitch and
/// the ways in. The main one needs no account: 'Start planning' (and Skip)
/// lead through the legal gate and onboarding into the app as a guest.
/// Making an account, or signing in to one, are the quieter links beneath.
/// The photo has no radius and bleeds to every edge; its
/// scrim ends on the theme canvas, which is what makes the image melt into the
/// page rather than stopping at a line.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const List<_IntroSlide> _slides = [
    _IntroSlide(
      headline: 'Every trip,\none place.',
      body:
          'Plan the days, pack the bag, split the spend and keep the '
          'photos — Odyssey holds the whole journey.',
      image: 'assets/intro/slide-1-open-road.jpg',
    ),
    _IntroSlide(
      headline: 'Plans that\nhold up.',
      body:
          'Build the itinerary day by day, tick activities off as you go, '
          'and keep the packing list honest.',
      image: 'assets/intro/slide-2-morning-gates.jpg',
    ),
    _IntroSlide(
      headline: 'The journal\nwrites itself.',
      body:
          'Photos land on the map where you took them. Spending, distance '
          'and days away add up on their own.',
      image: 'assets/intro/slide-3-high-desert.jpg',
    ),
  ];

  /// Set once a way out has been chosen, so a second tap during the await
  /// cannot record a second choice or start guest mode twice.
  bool _leaving = false;

  bool get _onLastSlide => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(analyticsServiceProvider).trackIntroShown());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    HapticFeedback.selectionClick();
    unawaited(
      ref.read(analyticsServiceProvider).trackIntroSlideViewed(slide: page),
    );
  }

  /// Reports how the user left, then marks the intro seen, which is what lets
  /// the router move them on.
  Future<void> _markSeen(String choice) async {
    unawaited(
      ref.read(analyticsServiceProvider).trackIntroChoice(choice: choice),
    );
    await ref.read(authProvider.notifier).setIntroSeen();
  }

  /// Leaves for one of the account screens.
  Future<void> _finish({
    required String destination,
    required String choice,
  }) async {
    if (_leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    // The legal gate stands between this button and where it points, and a
    // redirect cannot carry intent, so the choice is recorded for the router to
    // honour once the gate is cleared.
    setPendingAuthDestination(destination);
    await _markSeen(choice);
    if (mounted) context.go(destination);
  }

  /// Leaves to use the app without an account.
  ///
  /// Usually the legal gate is still ahead, so the choice is parked for the
  /// legal screen, which shows the guest warning once terms are agreed and
  /// then starts guest mode; the router carries on to onboarding and home.
  /// The warning waits until then so nothing stands between this button and
  /// the terms but the terms themselves.
  Future<void> _startAsGuest({required String choice}) async {
    if (_leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    final auth = ref.read(authProvider);
    final notifier = ref.read(authProvider.notifier);

    if (auth.isAuthenticated || auth.isGuest) {
      // Already signed in - a reinstall that kept its Keychain token - or
      // already a guest. There is nothing to start, and starting guest mode
      // would wipe their local data. The router takes them on as before.
      await _markSeen(choice);
      return;
    }

    if (auth.hasAcceptedTerms) {
      // No legal gate this time, so the warning is shown here instead.
      final confirmed = await confirmContinueAsGuest(context);
      if (!confirmed || !mounted) {
        _leaving = false;
        return;
      }
      // Guest first, then the intro: the redirect that follows must already
      // see a guest, or it sends them to sign in.
      await notifier.continueAsGuest(source: 'intro');
      await _markSeen(choice);
      return;
    }

    setPendingGuestStart();
    await _markSeen(choice);
  }

  void _advance() {
    if (!_onLastSlide) {
      _pageController.nextPage(
        duration: AppSizes.durationNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _startAsGuest(choice: 'guest');
    }
  }

  /// Room the pitch below the photo needs at the current text size: dots,
  /// a two-line headline, three lines of body, the button row, the
  /// 'No account needed' line, the links, padding and the gesture bar.
  static const double _pitchHeight = 410;

  double _photoHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(16) / 16;
    final pitch = _pitchHeight * scale.clamp(1.0, 1.6) + media.padding.bottom;
    return (media.size.height - pitch)
        .clamp(200.0, AppSizes.introPhotoHeight);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final slide = _slides[_page];

    // Light status-bar icons whatever the theme: the top of this screen is
    // a photograph under a dark scrim, not the app's canvas.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.canvas,
        body: Column(
          children: [
            // --- full-bleed photo ---
            // The photo gives way to the pitch, not the other way round: at a
            // fixed 520 the buttons sat below the fold on most phones (about
            // 960dp needed, most are 780-870dp tall), and half of new users
            // left on this screen.
            SizedBox(
              height: _photoHeight(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _slides.length,
                    itemBuilder: (context, index) =>
                        _IntroPhoto(slide: _slides[index], canvas: t.canvas),
                  ),
                  Positioned(
                    right: AppSizes.screenPadding,
                    top: 58,
                    child: Pressable(
                      onTap: () => _startAsGuest(choice: 'skip'),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.photoTagBg,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          border: Border.all(color: AppColors.photoTagBorder),
                        ),
                        child: Text(
                          'Skip',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onPhoto,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- pitch ---
            Expanded(
              child: SingleChildScrollView(
                // Clear of the gesture bar, which the photo above ignores.
                padding: EdgeInsets.fromLTRB(
                  AppSizes.authPadding,
                  26,
                  AppSizes.authPadding,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StepDots(count: _slides.length, index: _page),
                    const SizedBox(height: AppSizes.space22),
                    Text(
                      slide.headline,
                      style: AppTypography.heroTitle.copyWith(
                        fontSize: 42,
                        letterSpacing: -1.89,
                        height: 0.98,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        slide.body,
                        style: AppTypography.body.copyWith(color: t.ink2),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space26),
                    Row(
                      children: [
                        // Lime in both themes: this is the brand call to action,
                        // not an ordinary primary button.
                        Expanded(
                          child: PillButton(
                            label: _onLastSlide ? 'Start planning' : 'Next',
                            style: PillStyle.brand,
                            onPressed: _advance,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space12),
                        CircleButton(
                          glyph: '→',
                          size: AppSizes.circleIntroArrow,
                          glyphSize: 20,
                          onPressed: _advance,
                          semanticLabel:
                              _onLastSlide ? 'Start planning' : 'Next',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space10),
                    // The space is held on every slide so nothing below jumps
                    // when the last one fades this in under 'Start planning'.
                    AnimatedOpacity(
                      opacity: _onLastSlide ? 1 : 0,
                      duration: AppSizes.durationNormal,
                      child: Center(
                        child: Text(
                          'No account needed',
                          style: AppTypography.caption.copyWith(color: t.ink2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space8),
                    // A Wrap, not a Row: at large text sizes the pair runs
                    // onto two lines instead of overflowing.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _IntroLink(
                          label: 'Create account',
                          onTap: () => _finish(
                            destination: AppRoutes.register,
                            choice: 'register',
                          ),
                        ),
                        Text(
                          '·',
                          style: AppTypography.pill.copyWith(color: t.ink3),
                        ),
                        _IntroLink(
                          label: 'I already have an account',
                          onTap: () => _finish(
                            destination: AppRoutes.login,
                            choice: 'login',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the quiet text links under the main call to action.
class _IntroLink extends StatelessWidget {
  const _IntroLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space8,
          vertical: AppSizes.space6,
        ),
        child: Text(
          label,
          style: AppTypography.pill.copyWith(
            fontSize: 12.5,
            color: context.odyssey.ink3,
          ),
        ),
      ),
    );
  }
}

/// The photo block.Its scrim resolves to the theme canvas at the bottom, so
/// the image dissolves into the page instead of ending at an edge.
class _IntroPhoto extends StatelessWidget {
  const _IntroPhoto({required this.slide, required this.canvas});

  final _IntroSlide slide;
  final Color canvas;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoSurface(
          asset: slide.image,
          radius: 0,
          scrim: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  // 0.55, not the mock's 0.42, now that real photographs sit
                  // behind it. The three differ wildly at the top - open sky on
                  // two, a dark vault on the third - and at 0.42 the light ones
                  // left the strip mid-grey, where neither a dark nor a light
                  // status bar clock could be read. This puts every slide's top
                  // firmly in the dark, so one icon colour serves all three.
                  AppColors.obsidian.withValues(alpha: 0.55),
                  AppColors.obsidian.withValues(alpha: 0),
                  canvas,
                ],
                stops: const [0.20, 0.46, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
