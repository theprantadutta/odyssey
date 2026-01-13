import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String? _getFirstNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    final namePart = email.split('@').first;
    if (namePart.isEmpty) return null;
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    // Use displayName if available, otherwise fall back to extracting from email
    final firstName = user?.displayName ?? _getFirstNameFromEmail(user?.email);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.travel_explore,
                  color: AppColors.sunsetGold,
                  size: 24,
                ),
                const SizedBox(width: AppSizes.space8),
                Text('Odyssey', style: AppTypography.headlineMedium),
              ],
            ),
            Text(
              '${_getGreeting()}${firstName != null && firstName.isNotEmpty ? ', $firstName' : ''}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        toolbarHeight: 70,
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
            colors: [AppColors.frostedWhite, Colors.white],
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
