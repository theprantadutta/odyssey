import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import '../../../trips/data/models/default_trips_eligibility.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../walkthrough/presentation/providers/walkthrough_provider.dart';
import '../widgets/about_dialog.dart';
import '../widgets/legal_document_viewer.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '1.0.0';

  bool _isAddingSampleTrips = false;
  bool _isRemovingSampleTrips = false;

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

  Future<void> _handleDeleteAccount() async {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canDelete = controller.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            title: Text(
              'Delete Account',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.coralBurst,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This permanently deletes your account and all your trips, '
                  'memories, documents, and photos. This cannot be undone.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSizes.space16),
                Text(
                  'Type DELETE to confirm.',
                  style: AppTypography.bodySmall
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSizes.space8),
                TextField(
                  controller: controller,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTypography.labelLarge
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed:
                    canDelete ? () => Navigator.of(context).pop(true) : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.coralBurst,
                ),
                child: Text(
                  'Delete Account',
                  style: AppTypography.labelLarge.copyWith(
                    color: canDelete
                        ? AppColors.coralBurst
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();

    if (confirmed == true && mounted) {
      try {
        await ref.read(authProvider.notifier).deleteAccount();
        // Auth state becomes unauthenticated -> router redirects to login.
      } catch (e) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: AppColors.coralBurst,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// The tile stays visible once used, but goes inert - sample trips are a
  /// one-time-per-account action, so there is nothing left to tap.
  bool _canAddSampleTrips(AsyncValue<DefaultTripsEligibility> eligibility) {
    // While loading, or if the check itself failed, let the user try. The backend
    // is the real gate, so the worst case is a clear "already added" message.
    return eligibility.asData?.value.canAdd ?? true;
  }

  String _sampleTripsSubtitle(AsyncValue<DefaultTripsEligibility> eligibility) {
    final value = eligibility.asData?.value;
    if (value == null) return 'Fill your journal with demo trips to explore';
    if (!value.canAdd) return 'Already added to this account';
    return 'Fill your journal with demo trips to explore';
  }

  Future<void> _handleAddSampleTrips() async {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;
    final hasExistingTrips =
        ref.read(defaultTripsEligibilityProvider).asData?.value.hasExistingTrips ??
            ref.read(tripsProvider).trips.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Add Sample Trips',
          style: AppTypography.headlineSmall.copyWith(color: colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This adds four demo trips - Paris, Tokyo, Bali and New York - '
              'complete with activities, packing lists, expenses and memories.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasExistingTrips) ...[
              const SizedBox(height: AppSizes.space12),
              Text(
                'Your existing trips are not touched - the sample trips are added '
                'alongside them. You can delete any of them afterwards.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.warning),
              ),
            ],
            const SizedBox(height: AppSizes.space12),
            Text(
              'Sample trips can only be added once.',
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Add Trips',
              style: AppTypography.labelLarge.copyWith(color: AppColors.oceanTeal),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isAddingSampleTrips = true);

    try {
      final count = await ref.read(tripsProvider.notifier).addSampleTrips();
      if (!mounted) return;

      // Whether it succeeded or was already used, the server's answer changed.
      ref.invalidate(defaultTripsEligibilityProvider);

      if (count == null) {
        HapticFeedback.heavyImpact();
        _showSampleTripsMessage(
          'Sample trips have already been added to this account.',
          AppColors.warning,
        );
        return;
      }

      HapticFeedback.mediumImpact();
      _showSampleTripsMessage(
        '$count sample trips added to your journal.',
        AppColors.oceanTeal,
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showSampleTripsMessage('Failed to add sample trips: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isAddingSampleTrips = false);
    }
  }

  void _showSampleTripsMessage(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDeleteSampleTrips() async {
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
          'Remove Sample Trips',
          style: AppTypography.headlineSmall.copyWith(color: AppColors.coralBurst),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This permanently deletes the sample trips and everything in them - '
              'activities, packing lists, expenses, documents and memories. '
              'This cannot be undone.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.coralBurst),
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              'Only the sample trips are removed. Any trips you created yourself are '
              'left untouched.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              'If you want to keep one as a starting point, save it as a template '
              'first - you can then build new trips from it.',
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coralBurst),
            child: Text(
              'Remove Trips',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.coralBurst,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRemovingSampleTrips = true);

    try {
      final deleted = await ref.read(tripsProvider.notifier).deleteSampleTrips();
      if (!mounted) return;

      // Removing them frees the one-time allowance, so the add tile comes back.
      ref.invalidate(defaultTripsEligibilityProvider);

      HapticFeedback.mediumImpact();
      _showSampleTripsMessage(
        deleted == 0
            ? 'No sample trips to remove.'
            : '$deleted sample trips removed.',
        deleted == 0 ? AppColors.warning : AppColors.oceanTeal,
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showSampleTripsMessage('Failed to remove sample trips: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isRemovingSampleTrips = false);
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

  String _getThemeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Follows device settings',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

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
    final eligibility = ref.watch(defaultTripsEligibilityProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final isOnline = ref.watch(connectivityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LoadingOverlay(
      isLoading: authState.isLoading || _isAddingSampleTrips || _isRemovingSampleTrips,
      message: switch ((_isAddingSampleTrips, _isRemovingSampleTrips)) {
        (true, _) => 'Adding sample trips...',
        (_, true) => 'Removing sample trips...',
        _ => 'Signing out...',
      },
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
                SettingsTile(
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  isDestructive: true,
                  onTap: _handleDeleteAccount,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            // Trips Section
            FormSectionCard(
              title: 'Trips',
              icon: Icons.luggage_outlined,
              iconBackgroundColor: AppColors.oceanTeal.withValues(alpha: 0.15),
              iconColor: AppColors.oceanTeal,
              children: [
                SettingsTile(
                  title: 'Add Sample Trips',
                  subtitle: _sampleTripsSubtitle(eligibility),
                  onTap: _canAddSampleTrips(eligibility) ? _handleAddSampleTrips : null,
                  showChevron: _canAddSampleTrips(eligibility),
                ),
                if (eligibility.asData?.value.hasDemoTrips ?? false)
                  SettingsTile(
                    title: 'Remove Sample Trips',
                    subtitle: 'Delete the demo trips when you are done exploring',
                    isDestructive: true,
                    onTap: _handleDeleteSampleTrips,
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

            // Notifications Section
            FormSectionCard(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              iconBackgroundColor: AppColors.sunnyYellow.withValues(alpha: 0.15),
              iconColor: AppColors.sunnyYellow,
              children: [
                SettingsTile(
                  title: 'Notification Preferences',
                  subtitle: 'Categories, quiet hours',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(AppRoutes.notificationSettings);
                  },
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
                  title: 'Theme',
                  subtitle: _getThemeLabel(themeMode),
                  showChevron: false,
                ),
                const SizedBox(height: AppSizes.space8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      HapticFeedback.lightImpact();
                      ref.read(appThemeModeProvider.notifier).setMode(selected.first);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            // Legal Section
            FormSectionCard(
              title: 'Legal',
              icon: Icons.gavel_rounded,
              iconBackgroundColor: AppColors.sunnyYellow.withValues(alpha: 0.15),
              iconColor: AppColors.sunnyYellow,
              children: [
                SettingsTile(
                  title: 'Privacy Policy',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LegalDocumentViewer(
                        title: 'Privacy Policy',
                        assetPath: 'assets/legal/privacy.md',
                      ),
                    ));
                  },
                ),
                SettingsTile(
                  title: 'Terms & Conditions',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LegalDocumentViewer(
                        title: 'Terms & Conditions',
                        assetPath: 'assets/legal/terms.md',
                      ),
                    ));
                  },
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
                  title: 'Replay Walkthrough',
                  subtitle: 'See the guided tour again',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(walkthroughProvider.notifier).resetAll();
                    context.go(AppRoutes.home);
                  },
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
            if (kDebugMode) ...[
              const SizedBox(height: AppSizes.space16),
              FormSectionCard(
                title: 'Debug',
                icon: Icons.bug_report_outlined,
                iconBackgroundColor: AppColors.warning.withValues(alpha: 0.15),
                iconColor: AppColors.warning,
                children: [
                  SettingsTile(
                    title: 'Test Crash',
                    subtitle: 'Records a non-fatal test exception',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      FirebaseCrashlytics.instance.recordError(
                        Exception('Test crash from Odyssey settings'),
                        StackTrace.current,
                        reason: 'manual test from settings',
                      );
                    },
                  ),
                ],
              ),
            ],
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
