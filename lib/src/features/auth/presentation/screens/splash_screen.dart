import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_typography.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.travel_explore,
                size: 100,
                color: AppColors.sunsetGold,
              ),
              const SizedBox(height: 24),
              Text(
                'Odyssey',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.sunsetGold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
