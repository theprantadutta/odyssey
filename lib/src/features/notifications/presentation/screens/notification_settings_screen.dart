import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/form_section_card.dart';
import '../../../settings/presentation/widgets/settings_tile.dart';
import '../../data/models/notification_preference_model.dart';
import '../providers/notification_preference_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationPreferencesProvider.notifier).loadPreferences();
    });
  }

  Future<void> _updatePreference(NotificationPreferenceModel updated) async {
    final success = await ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(updated);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save preference'),
          backgroundColor: AppColors.coralBurst,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final state = ref.read(notificationPreferencesProvider);
    final prefs = state.preferences ?? const NotificationPreferenceModel();

    final currentTimeStr = isStart ? prefs.quietHoursStart : prefs.quietHoursEnd;
    TimeOfDay initialTime;

    if (currentTimeStr != null && currentTimeStr.contains(':')) {
      final parts = currentTimeStr.split(':');
      initialTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? (isStart ? 22 : 8),
        minute: int.tryParse(parts[1]) ?? 0,
      );
    } else {
      initialTime = TimeOfDay(hour: isStart ? 22 : 8, minute: 0);
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

      if (isStart) {
        _updatePreference(prefs.copyWith(quietHoursStart: timeStr));
      } else {
        _updatePreference(prefs.copyWith(quietHoursEnd: timeStr));
      }
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return '--:--';
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final tod = TimeOfDay(hour: hour, minute: minute);
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final displayHour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(notificationPreferencesProvider);
    final prefs = state.preferences ?? const NotificationPreferenceModel();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notification Preferences',
          style: AppTypography.titleLarge.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: BouncingDotsLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category toggles
                  FormSectionCard(
                    title: 'Categories',
                    icon: Icons.category_outlined,
                    iconBackgroundColor:
                        AppColors.skyBlue.withValues(alpha: 0.15),
                    iconColor: AppColors.skyBlue,
                    children: [
                      SettingsTile(
                        title: 'Invites & Sharing',
                        subtitle:
                            'Trip invites, responses, permission changes',
                        showChevron: false,
                        trailing: Switch(
                          value: prefs.invitesAndSharing,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            _updatePreference(
                                prefs.copyWith(invitesAndSharing: v));
                          },
                          activeThumbColor: AppColors.sunnyYellow,
                          activeTrackColor: AppColors.lemonLight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _updatePreference(prefs.copyWith(
                              invitesAndSharing: !prefs.invitesAndSharing));
                        },
                      ),
                      SettingsTile(
                        title: 'Content Updates',
                        subtitle:
                            'Memories, documents, activities, expenses added to trips',
                        showChevron: false,
                        trailing: Switch(
                          value: prefs.contentUpdates,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            _updatePreference(
                                prefs.copyWith(contentUpdates: v));
                          },
                          activeThumbColor: AppColors.sunnyYellow,
                          activeTrackColor: AppColors.lemonLight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _updatePreference(prefs.copyWith(
                              contentUpdates: !prefs.contentUpdates));
                        },
                      ),
                      SettingsTile(
                        title: 'Trip Reminders',
                        subtitle: 'Reminders before your trips start',
                        showChevron: false,
                        trailing: Switch(
                          value: prefs.tripReminders,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            _updatePreference(
                                prefs.copyWith(tripReminders: v));
                          },
                          activeThumbColor: AppColors.sunnyYellow,
                          activeTrackColor: AppColors.lemonLight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _updatePreference(prefs.copyWith(
                              tripReminders: !prefs.tripReminders));
                        },
                      ),
                      SettingsTile(
                        title: 'Achievements',
                        subtitle: 'When you earn new achievements',
                        showChevron: false,
                        trailing: Switch(
                          value: prefs.achievements,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            _updatePreference(
                                prefs.copyWith(achievements: v));
                          },
                          activeThumbColor: AppColors.sunnyYellow,
                          activeTrackColor: AppColors.lemonLight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _updatePreference(prefs.copyWith(
                              achievements: !prefs.achievements));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space16),

                  // Quiet hours
                  FormSectionCard(
                    title: 'Quiet Hours',
                    icon: Icons.do_not_disturb_on_outlined,
                    iconBackgroundColor:
                        AppColors.lavenderDream.withValues(alpha: 0.15),
                    iconColor: AppColors.lavenderDream,
                    children: [
                      SettingsTile(
                        title: 'Enable Quiet Hours',
                        subtitle:
                            'Delay push notifications during set hours',
                        showChevron: false,
                        trailing: Switch(
                          value: prefs.quietHoursEnabled,
                          onChanged: (v) {
                            HapticFeedback.lightImpact();
                            final tz = DateTime.now().timeZoneName;
                            _updatePreference(prefs.copyWith(
                              quietHoursEnabled: v,
                              quietHoursStart:
                                  v ? (prefs.quietHoursStart ?? '22:00') : prefs.quietHoursStart,
                              quietHoursEnd:
                                  v ? (prefs.quietHoursEnd ?? '08:00') : prefs.quietHoursEnd,
                              quietHoursTimeZone:
                                  v ? (prefs.quietHoursTimeZone ?? tz) : prefs.quietHoursTimeZone,
                            ));
                          },
                          activeThumbColor: AppColors.sunnyYellow,
                          activeTrackColor: AppColors.lemonLight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final v = !prefs.quietHoursEnabled;
                          final tz = DateTime.now().timeZoneName;
                          _updatePreference(prefs.copyWith(
                            quietHoursEnabled: v,
                            quietHoursStart:
                                v ? (prefs.quietHoursStart ?? '22:00') : prefs.quietHoursStart,
                            quietHoursEnd:
                                v ? (prefs.quietHoursEnd ?? '08:00') : prefs.quietHoursEnd,
                            quietHoursTimeZone:
                                v ? (prefs.quietHoursTimeZone ?? tz) : prefs.quietHoursTimeZone,
                          ));
                        },
                      ),
                      if (prefs.quietHoursEnabled) ...[
                        SettingsTile(
                          title: 'Start Time',
                          subtitle: _formatTime(prefs.quietHoursStart),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _selectTime(context, true);
                          },
                        ),
                        SettingsTile(
                          title: 'End Time',
                          subtitle: _formatTime(prefs.quietHoursEnd),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _selectTime(context, false);
                          },
                        ),
                        SettingsTile(
                          title: 'Timezone',
                          subtitle: prefs.quietHoursTimeZone ??
                              DateTime.now().timeZoneName,
                          showChevron: false,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSizes.space24),

                  // Info text
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space8),
                    child: Text(
                      'Disabled categories will still save notifications to your history, but push notifications will not be sent to your device.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space32),
                ],
              ),
            ),
    );
  }
}
