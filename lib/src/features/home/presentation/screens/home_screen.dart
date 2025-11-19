import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Odyssey',
          style: AppTypography.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.frostedWhite,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.travel_explore,
                  size: 100,
                  color: AppColors.sunsetGold,
                ),
                const SizedBox(height: AppSizes.space24),
                Text(
                  'Welcome to Odyssey',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.midnightBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.space16),
                if (user != null)
                  Text(
                    user.email,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSizes.space32),
                Text(
                  'Dashboard Coming Soon',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                Text(
                  'Your travel journey starts here',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
