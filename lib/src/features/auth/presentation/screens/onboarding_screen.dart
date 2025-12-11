import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/logger_service.dart';
import '../../../trips/data/repositories/trip_repository.dart';
import '../providers/auth_provider.dart';

/// Onboarding screen shown after registration
/// Asks user if they want pre-populated demo trips
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _keepClean = false; // Checkbox state: "No, I'll create my own"
  bool _isLoading = false;

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);

    try {
      if (!_keepClean) {
        // User wants default trips - call backend
        AppLogger.action('User chose to add demo trips');
        final tripRepository = TripRepository();
        await tripRepository.createDefaultTrips();
        AppLogger.info('Demo trips created successfully');
      } else {
        AppLogger.action('User chose to start fresh (no demo trips)');
      }

      // Mark onboarding as completed
      await ref.read(authProvider.notifier).completeOnboarding();
      AppLogger.lifecycle('Onboarding completed');

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      AppLogger.error('Onboarding failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Welcome Icon
                const Icon(
                  Icons.explore,
                  size: 80,
                  color: AppColors.sunsetGold,
                ),
                const SizedBox(height: AppSizes.space24),

                // Welcome Title
                Text(
                  'Welcome to Odyssey!',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.space16),

                // Description
                Text(
                  'Would you like to start with some sample trips to explore the app?',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.softGold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.space8),

                Text(
                  "We'll add 4 beautiful demo trips (Paris, Tokyo, Bali, NYC) so you can see how everything works.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.softGold.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Checkbox for "Keep Clean"
                InkWell(
                  onTap: () => setState(() => _keepClean = !_keepClean),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.space16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: _keepClean
                            ? AppColors.sunsetGold
                            : AppColors.softGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _keepClean,
                          onChanged: (value) =>
                              setState(() => _keepClean = value ?? false),
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.sunsetGold;
                            }
                            return Colors.transparent;
                          }),
                          checkColor: AppColors.midnightBlue,
                          side: BorderSide(
                            color: AppColors.softGold.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Expanded(
                          child: Text(
                            "No thanks, I'll create my own trips",
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.space32),

                // Continue Button
                CustomButton(
                  text: _keepClean
                      ? 'Start Fresh'
                      : 'Add Demo Trips & Continue',
                  onPressed: _isLoading ? null : _handleContinue,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: AppSizes.space48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
