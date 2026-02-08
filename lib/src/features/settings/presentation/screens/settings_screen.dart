import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/theme_provider.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/form_section_card.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/data/models/subscription_model.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../widgets/about_dialog.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '1.0.0';

  Future<void> _handleSignOut() async {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Sign Out',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coralBurst),
            child: Text(
              'Sign Out',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.coralBurst,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _handleManageSubscription() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.subscription);
  }

  void _handleShowAbout() {
    HapticFeedback.lightImpact();
    showAboutOdysseyDialog(
      context: context,
      appVersion: _appVersion,
    );
  }

  void _handleToggleTheme() {
    HapticFeedback.lightImpact();
    ref.read(appThemeModeProvider.notifier).toggle();
  }

  String _getTierDisplayName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final isOnline = ref.watch(connectivityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LoadingOverlay(
      isLoading: authState.isLoading,
      message: 'Signing out...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Settings',
            style: AppTypography.headlineMedium.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            FormSectionCard(
              title: 'Account',
              icon: Icons.person_outline_rounded,
              iconBackgroundColor: AppColors.skyBlue.withValues(alpha: 0.15),
              iconColor: AppColors.skyBlue,
              children: [
                SettingsTile(
                  title: 'Email',
                  subtitle: authState.user?.email ?? 'Not available',
                  showChevron: false,
                ),
                if (authState.user?.displayName != null &&
                    authState.user!.displayName!.isNotEmpty)
                  SettingsTile(
                    title: 'Display Name',
                    subtitle: authState.user!.displayName,
                    showChevron: false,
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            // Subscription Section
            FormSectionCard(
              title: 'Subscription',
              icon: Icons.diamond_outlined,
              iconBackgroundColor: AppColors.lavenderDream.withValues(alpha: 0.15),
              iconColor: AppColors.lavenderDream,
              children: [
                SettingsTile(
                  title: 'Current Plan',
                  subtitle: subscriptionState.isLoading
                      ? 'Loading...'
                      : _getTierDisplayName(subscriptionState.tier),
                  onTap: _handleManageSubscription,
                ),
                if (!subscriptionState.isPremium && !subscriptionState.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.space8),
                    child: SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'Upgrade to Premium',
                        onPressed: _handleManageSubscription,
                        backgroundColor: AppColors.lavenderDream,
                        textColor: AppColors.pureWhite,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            // Appearance Section
            FormSectionCard(
              title: 'Appearance',
              icon: Icons.palette_outlined,
              iconBackgroundColor: AppColors.oceanTeal.withValues(alpha: 0.15),
              iconColor: AppColors.oceanTeal,
              children: [
                SettingsTile(
                  title: 'Dark Mode',
                  subtitle: isDarkMode ? 'On' : 'Off',
                  showChevron: false,
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (_) => _handleToggleTheme(),
                    activeThumbColor: AppColors.sunnyYellow,
                    activeTrackColor: AppColors.lemonLight,
                  ),
                  onTap: _handleToggleTheme,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            // About Section
            FormSectionCard(
              title: 'About',
              icon: Icons.info_outline_rounded,
              iconBackgroundColor: AppColors.coralBurst.withValues(alpha: 0.15),
              iconColor: AppColors.coralBurst,
              children: [
                SettingsTile(
                  title: 'Network Status',
                  subtitle: isOnline ? 'Online' : 'Offline',
                  showChevron: false,
                  trailing: Icon(
                    isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 20,
                    color: isOnline ? AppColors.oceanTeal : colorScheme.onSurfaceVariant,
                  ),
                ),
                SettingsTile(
                  title: 'App Version',
                  subtitle: _appVersion,
                  onTap: _handleShowAbout,
                ),
                SettingsTile(
                  title: 'Developer',
                  subtitle: 'Pranta Dutta',
                  onTap: _handleShowAbout,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Sign Out',
                isOutlined: true,
                backgroundColor: AppColors.coralBurst,
                textColor: AppColors.coralBurst,
                onPressed: _handleSignOut,
                isLoading: authState.isLoading,
              ),
            ),
            const SizedBox(height: AppSizes.space32),
          ],
        ),
      ),
    ),
  );
}
}
