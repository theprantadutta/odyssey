import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/widgets/odyssey/brand_mark.dart';

/// The screen that takes over from the native splash while auth resolves.
///
/// It is drawn to be indistinguishable from the native splash it replaces:
/// the same ink field, the same lime mark at the same size, in both
/// appearances. The handover should be invisible — the only thing that ever
/// appears is a quiet progress hairline once the wait runs long enough to
/// need explaining.
///
/// This screen does not follow the theme. The native splash cannot, so
/// matching it means pinning the colours here too.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void initState() {
    super.initState();

    // Lifting the native splash here, rather than in main, keeps it covering
    // the app until something identical is on screen. Anything that renders
    // for a frame before this — a transient auth route, a first build — stays
    // hidden behind it.
    FlutterNativeSplash.remove();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The mark is already on screen from the native splash, so it does not
    // animate in. Only the progress hairline below it does, and only after a
    // beat, so a fast launch never shows it at all.
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Stack(
        children: [
          const Center(child: OdysseyMark(size: 119, tone: MarkTone.lime)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: FadeTransition(
              opacity: fade,
              child: const Center(child: _SplashProgress()),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 48px lime hairline that travels back and forth. No spinner — this system
/// allows one only on button submit.
class _SplashProgress extends StatefulWidget {
  const _SplashProgress();

  @override
  State<_SplashProgress> createState() => _SplashProgressState();
}

class _SplashProgressState extends State<_SplashProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SizedBox(
      width: 48,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: reduceMotion
            ? null
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Align(
                  alignment: Alignment(
                    Curves.easeInOut.transform(_controller.value) * 2 - 1,
                    0,
                  ),
                  child: Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
