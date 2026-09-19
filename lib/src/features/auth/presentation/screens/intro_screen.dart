import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

/// One slide of the intro.
class _IntroSlide {
  const _IntroSlide({
    required this.headline,
    required this.body,
    required this.tag,
    required this.gradient,
  });

  /// Set very large and tight, and deliberately broken across two lines.
  final String headline;

  final String body;

  /// The `photo · …` label on the placeholder image.
  final String tag;

  final LinearGradient gradient;
}

/// Onboarding — screen 3a.
///
/// A 520px full-bleed photo that dissolves into the canvas, then the pitch and
/// the two ways in. The photo has no radius and bleeds to every edge; its
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
      body: 'Plan the days, pack the bag, split the spend and keep the '
          'photos — Odyssey holds the whole journey.',
      tag: 'photo · open road',
      gradient: AppColors.kyotoGradient,
    ),
    _IntroSlide(
      headline: 'Plans that\nhold up.',
      body: 'Build the itinerary day by day, tick activities off as you go, '
          'and keep the packing list honest.',
      tag: 'photo · morning gates',
      gradient: AppColors.greenStayGradient,
    ),
    _IntroSlide(
      headline: 'The journal\nwrites itself.',
      body: 'Photos land on the map where you took them. Spending, distance '
          'and days away add up on their own.',
      tag: 'photo · high desert',
      gradient: AppColors.autumnGradient,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    HapticFeedback.selectionClick();
  }

  Future<void> _finish({required String destination}) async {
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).setIntroSeen();
    if (mounted) context.go(destination);
  }

  void _advance() {
    if (_page < _slides.length - 1) {
      _pageController.nextPage(
        duration: AppSizes.durationNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish(destination: AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final slide = _slides[_page];

    return Scaffold(
      backgroundColor: t.canvas,
      body: Column(
        children: [
          // --- full-bleed photo ---
          SizedBox(
            height: AppSizes.introPhotoHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) => _IntroPhoto(
                    slide: _slides[index],
                    canvas: t.canvas,
                  ),
                ),
                Positioned(
                  left: AppSizes.screenPadding,
                  top: 62,
                  child: PhotoTag(slide.tag),
                ),
                Positioned(
                  right: AppSizes.screenPadding,
                  top: 58,
                  child: Pressable(
                    onTap: () => _finish(destination: AppRoutes.login),
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
              padding: const EdgeInsets.fromLTRB(
                AppSizes.authPadding,
                30,
                AppSizes.authPadding,
                32,
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
                          label: _page == _slides.length - 1
                              ? 'Create account'
                              : 'Next',
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
                        semanticLabel: 'Next',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space16),
                  Center(
                    child: Pressable(
                      onTap: () => _finish(destination: AppRoutes.login),
                      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space12,
                          vertical: AppSizes.space6,
                        ),
                        child: Text(
                          'I already have an account',
                          style: AppTypography.pill.copyWith(
                            fontSize: 12.5,
                            color: t.ink3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo block. Its scrim resolves to the theme canvas at the bottom, so
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
          gradient: slide.gradient,
          radius: 0,
          scrim: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.obsidian.withValues(alpha: 0.42),
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
