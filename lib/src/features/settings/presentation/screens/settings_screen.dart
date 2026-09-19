import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/theme/theme_provider.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/providers/app_version_provider.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/task_routes.dart';
import '../../../ads/presentation/providers/ads_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/models/notification_preference_model.dart';
import '../../../notifications/presentation/providers/notification_preference_provider.dart';
import '../../../subscription/data/models/subscription_model.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../trips/data/models/default_trips_eligibility.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../../../walkthrough/presentation/providers/walkthrough_provider.dart';
import '../widgets/about_dialog.dart';
import '../widgets/legal_document_viewer.dart';
import '../widgets/settings_rows.dart';

/// Profile and settings — screen 3m, and the "You" tab.
///
/// The design lays this out as a profile card, an appearance control, one
/// grouped card of switches and one of navigation rows. Everything the old
/// screen could do still lives here; the extra items fold into the grouped
/// cards rather than being dropped.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Shown for the blink before the bundle's version resolves.
  static const String _versionPlaceholder = '…';

  bool _isAddingSampleTrips = false;
  bool _isRemovingSampleTrips = false;

  @override
  void initState() {
    super.initState();
    // The toggles below are the real server-side preferences, so they need
    // fetching before they can be shown in their true state.
    Future.microtask(
      () => ref.read(notificationPreferencesProvider.notifier).loadPreferences(),
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _handleSignOut() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Sign out',
      body: const ['You can sign back in whenever you like.'],
      confirmLabel: 'Sign out',
    );
    if (confirmed && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete account',
      // Two separate promises, because the server makes two. Signing out is
      // immediate and certain; removing the data happens afterwards, on the
      // server, and nothing here knows when it finishes — so nothing here
      // says when it will.
      body: const [
        'This deletes your account and all your trips, memories, documents, '
            'and photos. You will be signed out straight away and will not be '
            'able to sign in again.',
        'Removing your data from our servers happens afterwards. This cannot '
            'be undone.',
      ],
      confirmLabel: 'Delete account',
      typeToConfirm: 'DELETE',
    );

    if (!confirmed || !mounted) return;

    try {
      final receipt = await ref.read(authProvider.notifier).deleteAccount();

      // What the server actually said, not what the tap implied. It accepted
      // the request and took the account's access away; the data goes
      // afterwards, and this screen is never told when. Claiming "deleted"
      // here would be a promise made on the server's behalf that it has not
      // yet kept.
      if (mounted && !receipt.deletionCompleted) {
        showOdysseyMessage(
          context,
          receipt.alreadyRequested
              ? 'Your account is already being deleted. You have been signed '
                    'out and cannot sign in again.'
              : 'Deletion requested. You have been signed out and cannot sign '
                    'in again. Removing your data is in progress.',
        );
      }
      // Auth state becomes unauthenticated -> router redirects to login.
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'Could not request account deletion: $e');
    }
  }

  /// The row stays visible once used, but goes inert — sample trips are a
  /// one-time-per-account action, so there is nothing left to tap.
  bool _canAddSampleTrips(AsyncValue<DefaultTripsEligibility> eligibility) {
    // While loading, or if the check itself failed, let the user try. The
    // backend is the real gate, so the worst case is a clear message.
    return eligibility.asData?.value.canAdd ?? true;
  }

  String _sampleTripsMeta(AsyncValue<DefaultTripsEligibility> eligibility) {
    if (_isAddingSampleTrips) return 'Adding…';
    if (!_canAddSampleTrips(eligibility)) return 'Already added to this account';
    return 'Four demo trips, fully populated';
  }

  Future<void> _handleAddSampleTrips() async {
    final hasExistingTrips =
        ref.read(defaultTripsEligibilityProvider).asData?.value.hasExistingTrips ??
        ref.read(tripsProvider).trips.isNotEmpty;

    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Add sample trips',
      body: [
        'This adds four demo trips — Paris, Tokyo, Bali and New York — '
            'complete with activities, packing lists, expenses and memories.',
        if (hasExistingTrips)
          'Your existing trips are not touched; the sample trips are added '
              'alongside them. You can delete any of them afterwards.',
        'Sample trips can only be added once.',
      ],
      confirmLabel: 'Add trips',
    );

    if (!confirmed || !mounted) return;
    setState(() => _isAddingSampleTrips = true);

    try {
      final count = await ref.read(tripsProvider.notifier).addSampleTrips();
      if (!mounted) return;

      // Whether it succeeded or was already used, the server's answer changed.
      ref.invalidate(defaultTripsEligibilityProvider);

      if (count == null) {
        HapticFeedback.heavyImpact();
        showOdysseyMessage(
          context,
          'Sample trips have already been added to this account.',
        );
        return;
      }

      HapticFeedback.mediumImpact();
      showOdysseyMessage(context, '$count sample trips added to your journal.');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'Failed to add sample trips: $e');
    } finally {
      if (mounted) setState(() => _isAddingSampleTrips = false);
    }
  }

  Future<void> _handleDeleteSampleTrips() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Remove sample trips',
      body: const [
        'This permanently deletes the sample trips and everything in them — '
            'activities, packing lists, expenses, documents and memories. '
            'This cannot be undone.',
        'Only the sample trips are removed. Any trips you created yourself '
            'are left untouched.',
        'If you want to keep one as a starting point, save it as a template '
            'first — you can then build new trips from it.',
      ],
      confirmLabel: 'Remove trips',
    );

    if (!confirmed || !mounted) return;
    setState(() => _isRemovingSampleTrips = true);

    try {
      final deleted = await ref.read(tripsProvider.notifier).deleteSampleTrips();
      if (!mounted) return;

      // Removing them frees the one-time allowance, so the add row comes back.
      ref.invalidate(defaultTripsEligibilityProvider);

      HapticFeedback.mediumImpact();
      showOdysseyMessage(
        context,
        deleted == 0
            ? 'No sample trips to remove.'
            : '$deleted sample trips removed.',
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'Failed to remove sample trips: $e');
    } finally {
      if (mounted) setState(() => _isRemovingSampleTrips = false);
    }
  }

  void _openLegal(String title, String assetPath) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.legalViewer),
        builder: (_) => LegalDocumentViewer(title: title, assetPath: assetPath),
      ),
    );
  }

  void _handleShowAbout() {
    HapticFeedback.lightImpact();
    showAboutOdysseyDialog(
      context: context,
      appVersion:
          ref.read(appVersionProvider).asData?.value ?? _versionPlaceholder,
    );
  }

  Future<void> _setPreference(
    NotificationPreferenceModel Function(NotificationPreferenceModel) update,
  ) async {
    final current =
        ref.read(notificationPreferencesProvider).preferences ??
        const NotificationPreferenceModel();
    HapticFeedback.selectionClick();

    final ok = await ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(update(current));

    if (!ok && mounted) {
      showOdysseyMessage(context, 'That preference did not save. Try again.');
    }
  }

  // ------------------------------------------------------------------
  // Labels
  // ------------------------------------------------------------------

  static const _themeLabels = ['Light', 'Dark', 'System'];

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  ThemeMode _themeMode(String label) => switch (label) {
    'Light' => ThemeMode.light,
    'Dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _themeCaption(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Locked to light for every screen.',
    ThemeMode.dark => 'Locked to dark for every screen.',
    ThemeMode.system => 'Follows your device setting.',
  };

  String _tierName(SubscriptionTier tier) => switch (tier) {
    SubscriptionTier.free => 'Free',
    SubscriptionTier.premium => 'Pro',
  };

  String? _firstName(String? displayName, String? email) {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email?.split('@').first;
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final authState = ref.watch(authProvider);
    final appVersion = ref.watch(appVersionProvider);
    final eligibility = ref.watch(defaultTripsEligibilityProvider);
    final subscription = ref.watch(subscriptionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final isOnline = ref.watch(connectivityProvider);
    final prefsState = ref.watch(notificationPreferencesProvider);
    final prefs = prefsState.preferences ?? const NotificationPreferenceModel();

    final user = authState.user;
    final name = _firstName(user?.displayName, user?.email) ?? 'Traveller';
    final isPremium = subscription.isPremium;

    return OdysseyScaffold(
      extendBehindNav: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.contentTop,
          AppSizes.screenPadding,
          navScrollSpacer(context),
        ),
        children: [
          Text('You', style: AppTypography.screenTitle.copyWith(color: t.ink)),
          const SizedBox(height: AppSizes.space20),

          // --- profile ---
          OdysseyCard(
            radius: AppSizes.radiusPanel,
            padding: const EdgeInsets.all(AppSizes.space18),
            child: Row(
              children: [
                AvatarCircle(name: name, size: AppSizes.circleAvatarLarge),
                const SizedBox(width: AppSizes.space14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: AppTypography.cardTitleLarge.copyWith(
                          color: t.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: AppTypography.pill.copyWith(color: t.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isPremium) ...[
                  const SizedBox(width: AppSizes.space10),
                  const OdysseyBadge('PRO'),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space12),

          // --- appearance ---
          // This control is the real theme switch.
          OdysseyCard(
            radius: AppSizes.radiusPanel,
            padding: const EdgeInsets.all(AppSizes.space18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EyebrowLabel('Appearance'),
                const SizedBox(height: AppSizes.space14),
                SegmentedControl(
                  labels: _themeLabels,
                  selected: _themeLabel(themeMode),
                  onSelected: (label) {
                    HapticFeedback.selectionClick();
                    ref
                        .read(appThemeModeProvider.notifier)
                        .setMode(_themeMode(label));
                  },
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  _themeCaption(themeMode),
                  style: AppTypography.legend.copyWith(color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space12),

          // --- notification toggles ---
          GroupedCard(
            children: [
              SettingsToggleRow(
                icon: Icons.notifications_none_rounded,
                label: 'Trip reminders',
                meta: 'Countdowns and departure nudges',
                value: prefs.tripReminders,
                onChanged: (v) => _setPreference(
                  (p) => p.copyWith(tripReminders: v),
                ),
              ),
              SettingsToggleRow(
                icon: Icons.group_outlined,
                label: 'Shared trip activity',
                meta: 'Invites and changes from travel companions',
                value: prefs.invitesAndSharing,
                circleChip: true,
                onChanged: (v) => _setPreference(
                  (p) => p.copyWith(invitesAndSharing: v),
                ),
              ),
              SettingsToggleRow(
                icon: Icons.photo_camera_outlined,
                label: 'Memory prompts',
                meta: 'Nudges to add photos while you travel',
                value: prefs.contentUpdates,
                onChanged: (v) => _setPreference(
                  (p) => p.copyWith(contentUpdates: v),
                ),
              ),
              SettingsToggleRow(
                icon: Icons.emoji_events_outlined,
                label: 'Achievements',
                meta: 'Badges and points you unlock',
                value: prefs.achievements,
                circleChip: true,
                onChanged: (v) => _setPreference(
                  (p) => p.copyWith(achievements: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space12),

          // --- navigation ---
          GroupedCard(
            children: [
              SettingsNavRow(
                icon: Icons.tune_rounded,
                label: 'Notification detail',
                value: 'Quiet hours',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.notificationSettings);
                },
              ),
              SettingsNavRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Subscription',
                circleChip: true,
                value: subscription.isLoading
                    ? '…'
                    : _tierName(subscription.tier),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.subscription);
                },
              ),
              SettingsNavRow(
                icon: Icons.group_outlined,
                label: 'Shared trips',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.sharedTrips);
                },
              ),
              SettingsNavRow(
                icon: Icons.emoji_events_outlined,
                label: 'Achievements',
                circleChip: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.achievements);
                },
              ),
              SettingsNavRow(
                icon: Icons.insights_outlined,
                label: 'Statistics',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.statistics);
                },
              ),
              SettingsNavRow(
                icon: Icons.dashboard_customize_outlined,
                label: 'Templates',
                circleChip: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.templates);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space12),

          // --- trips & data ---
          GroupedCard(
            children: [
              SettingsNavRow(
                icon: Icons.auto_awesome_outlined,
                label: 'Add sample trips',
                meta: _sampleTripsMeta(eligibility),
                onTap: _canAddSampleTrips(eligibility) && !_isAddingSampleTrips
                    ? _handleAddSampleTrips
                    : null,
              ),
              if (!_canAddSampleTrips(eligibility))
                SettingsNavRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove sample trips',
                  circleChip: true,
                  meta: _isRemovingSampleTrips
                      ? 'Removing…'
                      : 'Delete the demo trips when you are done',
                  onTap: _isRemovingSampleTrips ? null : _handleDeleteSampleTrips,
                ),
              SettingsNavRow(
                icon: Icons.replay_rounded,
                label: 'Replay walkthrough',
                meta: 'See the guided tour again',
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(walkthroughProvider.notifier).resetAll();
                  context.go(AppRoutes.home);
                },
              ),
              SettingsNavRow(
                icon: isOnline
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                label: 'Network',
                circleChip: true,
                value: isOnline ? 'Online' : 'Offline',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space12),

          // --- privacy & about ---
          GroupedCard(
            children: [
              SettingsNavRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: () => _openLegal('Privacy Policy', 'assets/legal/privacy.md'),
              ),
              SettingsNavRow(
                icon: Icons.gavel_outlined,
                label: 'Terms & conditions',
                circleChip: true,
                onTap: () =>
                    _openLegal('Terms & Conditions', 'assets/legal/terms.md'),
              ),
              if (ref.watch(privacyOptionsRequiredProvider))
                SettingsNavRow(
                  icon: Icons.ads_click_outlined,
                  label: 'Ad privacy options',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await ref.read(showPrivacyOptionsProvider)();
                    if (!context.mounted) return;
                    showOdysseyMessage(
                      context,
                      'Your ad preferences have been updated.',
                    );
                  },
                ),
              SettingsNavRow(
                icon: Icons.info_outline_rounded,
                label: 'About Odyssey',
                circleChip: true,
                value: appVersion.asData?.value ?? _versionPlaceholder,
                onTap: _handleShowAbout,
              ),
              SettingsNavRow(
                icon: Icons.person_remove_outlined,
                label: 'Delete account',
                meta: 'Permanently delete your account and data',
                onTap: _handleDeleteAccount,
              ),
            ],
          ),

          if (kDebugMode) ...[
            const SizedBox(height: AppSizes.space12),
            GroupedCard(
              children: [
                SettingsNavRow(
                  icon: Icons.bug_report_outlined,
                  label: 'Test crash',
                  meta: 'Records a non-fatal test exception',
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

          const SizedBox(height: AppSizes.space24),
          PillButton(
            label: 'Sign out',
            style: PillStyle.outline,
            isLoading: authState.isLoading,
            onPressed: _handleSignOut,
            padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
          ),
          const SizedBox(height: AppSizes.space18),
          Center(
            child: Text(
              'ODYSSEY 2.0 · BUILD '
              '${appVersion.asData?.value ?? _versionPlaceholder}',
              style: AppTypography.monoDivider.copyWith(
                color: t.ink3,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
