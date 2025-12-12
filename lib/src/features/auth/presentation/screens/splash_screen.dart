import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../../../common/animations/loading/bouncing_dots_loader.dart';

/// Playful splash screen with bouncy animations
/// Soft cream gradient background with yellow accents
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.slow,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.bouncyEnter,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.softCream,
              AppColors.snowWhite,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.lemonLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.travel_explore,
                        size: 80,
                        color: AppColors.sunnyYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Animated Title
                  Transform.translate(
                    offset: Offset(0, 20 * (1 - _bounceAnimation.value)),
                    child: Opacity(
                      opacity: _bounceAnimation.value.clamp(0.0, 1.0),
                      child: Text(
                        'Odyssey',
                        style: AppTypography.brandLarge.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Transform.translate(
                    offset: Offset(0, 15 * (1 - _bounceAnimation.value)),
                    child: Opacity(
                      opacity: (_bounceAnimation.value - 0.2).clamp(0.0, 1.0),
                      child: Text(
                        'Your Journey Awaits',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Bouncing Dots Loader
                  const BouncingDotsLoader(
                    dotSize: 12,
                    spacing: 6,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
