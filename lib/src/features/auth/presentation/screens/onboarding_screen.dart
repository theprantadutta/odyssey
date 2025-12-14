import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../../../common/animations/animated_widgets/animated_button.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/logger_service.dart';
import '../../../trips/data/repositories/trip_repository.dart';
import '../providers/auth_provider.dart';

/// Playful onboarding screen shown after registration
/// Asks user if they want pre-populated demo trips
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  bool _keepClean = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppAnimations.bouncyEnter,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      if (!_keepClean) {
        AppLogger.action('User chose to add demo trips');
        final tripRepository = TripRepository();
        try {
          await tripRepository.createDefaultTrips();
          AppLogger.info('Demo trips created successfully');
        } catch (e) {
          // If user already has trips (409 error), that's fine - just continue
          if (e.toString().contains('already has trips') || e.toString().contains('409')) {
            AppLogger.info('User already has trips, skipping demo trip creation');
          } else {
            rethrow;
          }
        }
      } else {
        AppLogger.action('User chose to start fresh (no demo trips)');
      }

      await ref.read(authProvider.notifier).completeOnboarding();
      AppLogger.lifecycle('Onboarding completed');

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      AppLogger.error('Onboarding failed', e);
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      48, // padding
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSizes.space24),

                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: AppSizes.space32),

                    // Demo Trips Card
                    _buildDemoTripsCard(),
                    const SizedBox(height: AppSizes.space24),

                    // Keep Clean Checkbox
                    _buildKeepCleanOption(),
                    const SizedBox(height: AppSizes.space32),

                    // Continue Button
                    AnimatedButton(
                      text: _keepClean
                          ? 'Start Fresh'
                          : 'Add Demo Trips & Continue',
                      onPressed: _isLoading ? null : _handleContinue,
                      isLoading: _isLoading,
                      icon: _keepClean
                          ? Icons.arrow_forward_rounded
                          : Icons.auto_awesome_rounded,
                      height: AppSizes.buttonHeightLg,
                      width: double.infinity,
                    ),

                    const SizedBox(height: AppSizes.space24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        // Animated Icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(28),
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
                  Icons.celebration_rounded,
                  size: 64,
                  color: AppColors.sunnyYellow,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSizes.space24),

        // Welcome Title
        Text(
          'Welcome to Odyssey!',
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.charcoal,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.space12),

        // Subtitle
        Text(
          'Ready to plan your next adventure?',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.slate,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDemoTripsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusOngoingBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: AppColors.oceanTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSizes.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Trips',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      'Explore with demo content',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          const Divider(color: AppColors.cloudGray, height: 1),
          const SizedBox(height: AppSizes.space16),

          // Demo trip previews
          _buildDemoTripItem(
            icon: Icons.castle_rounded,
            title: 'Paris, France',
            color: AppColors.coralBurst,
          ),
          const SizedBox(height: AppSizes.space12),
          _buildDemoTripItem(
            icon: Icons.temple_buddhist_rounded,
            title: 'Tokyo, Japan',
            color: AppColors.lavenderDream,
          ),
          const SizedBox(height: AppSizes.space12),
          _buildDemoTripItem(
            icon: Icons.beach_access_rounded,
            title: 'Bali, Indonesia',
            color: AppColors.oceanTeal,
          ),
          const SizedBox(height: AppSizes.space12),
          _buildDemoTripItem(
            icon: Icons.location_city_rounded,
            title: 'New York, USA',
            color: AppColors.skyBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildDemoTripItem({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.charcoal,
            ),
          ),
        ),
        Icon(
          Icons.check_circle_rounded,
          color: AppColors.success.withValues(alpha: 0.5),
          size: 18,
        ),
      ],
    );
  }

  Widget _buildKeepCleanOption() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _keepClean = !_keepClean);
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: _keepClean ? AppColors.lemonLight : AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: _keepClean ? AppColors.sunnyYellow : AppColors.cloudGray,
            width: 2,
          ),
          boxShadow: _keepClean ? AppSizes.softShadow : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppAnimations.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _keepClean ? AppColors.sunnyYellow : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _keepClean ? AppColors.sunnyYellow : AppColors.slate,
                  width: 2,
                ),
              ),
              child: _keepClean
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.charcoal,
                    )
                  : null,
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No thanks, I'll create my own",
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    'Start with a clean slate',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
