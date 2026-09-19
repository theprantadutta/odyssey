import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../settings/presentation/widgets/settings_rows.dart';
import '../../data/models/notification_preference_model.dart';
import '../providers/notification_preference_provider.dart';

/// Notification detail — the categories and quiet hours behind the toggles on
/// the settings screen.
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

  Future<void> _update(NotificationPreferenceModel updated) async {
    HapticFeedback.selectionClick();
    final saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .updatePreferences(updated);

    if (!saved && mounted) {
      showOdysseyMessage(context, 'That preference did not save. Try again.');
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final prefs =
        ref.read(notificationPreferencesProvider).preferences ??
        const NotificationPreferenceModel();

    final stored = isStart ? prefs.quietHoursStart : prefs.quietHoursEnd;
    final initial = _parse(stored) ?? TimeOfDay(hour: isStart ? 22 : 8, minute: 0);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    await _update(
      isStart
          ? prefs.copyWith(quietHoursStart: value)
          : prefs.copyWith(quietHoursEnd: value),
    );
  }

  static TimeOfDay? _parse(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _format(String? value) {
    final time = _parse(value);
    if (time == null) return '—';
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(notificationPreferencesProvider);
    final prefs = state.preferences ?? const NotificationPreferenceModel();

    return OdysseyScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.contentTop,
          AppSizes.screenPadding,
          AppSizes.scrollBottom,
        ),
        children: [
          ScreenHeader(title: 'Settings', onBack: () => context.pop()),
          const SizedBox(height: AppSizes.space20),
          Text(
            'What reaches\nyou',
            style: AppTypography.screenTitle.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSizes.space20),

          if (state.isLoading && state.preferences == null)
            const Column(
              children: [
                Skeleton.row(),
                SizedBox(height: AppSizes.space12),
                Skeleton.row(),
              ],
            )
          else ...[
            GroupedCard(
              children: [
                SettingsToggleRow(
                  icon: Icons.group_outlined,
                  label: 'Invites and sharing',
                  meta: 'When someone shares a trip with you',
                  value: prefs.invitesAndSharing,
                  onChanged: (v) =>
                      _update(prefs.copyWith(invitesAndSharing: v)),
                ),
                SettingsToggleRow(
                  icon: Icons.photo_camera_outlined,
                  label: 'Content updates',
                  meta: 'Changes to trips you follow',
                  value: prefs.contentUpdates,
                  circleChip: true,
                  onChanged: (v) => _update(prefs.copyWith(contentUpdates: v)),
                ),
                SettingsToggleRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Trip reminders',
                  meta: 'Countdowns and departure nudges',
                  value: prefs.tripReminders,
                  onChanged: (v) => _update(prefs.copyWith(tripReminders: v)),
                ),
                SettingsToggleRow(
                  icon: Icons.emoji_events_outlined,
                  label: 'Achievements',
                  meta: 'Badges and points you unlock',
                  value: prefs.achievements,
                  circleChip: true,
                  onChanged: (v) => _update(prefs.copyWith(achievements: v)),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space18),

            const EyebrowLabel('Quiet hours'),
            const SizedBox(height: AppSizes.space12),
            GroupedCard(
              children: [
                SettingsToggleRow(
                  icon: Icons.bedtime_outlined,
                  label: 'Hold notifications',
                  meta: 'Nothing arrives between these times',
                  value: prefs.quietHoursEnabled,
                  onChanged: (v) =>
                      _update(prefs.copyWith(quietHoursEnabled: v)),
                ),
                // The times stay visible but go inert when quiet hours are
                // off, so the setting explains itself without being tappable.
                SettingsNavRow(
                  icon: Icons.nightlight_outlined,
                  label: 'From',
                  circleChip: true,
                  value: _format(prefs.quietHoursStart),
                  onTap: prefs.quietHoursEnabled
                      ? () => _pickTime(isStart: true)
                      : null,
                ),
                SettingsNavRow(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Until',
                  value: _format(prefs.quietHoursEnd),
                  onTap: prefs.quietHoursEnabled
                      ? () => _pickTime(isStart: false)
                      : null,
                ),
              ],
            ),

            if (state.error != null) ...[
              const SizedBox(height: AppSizes.space14),
              Text(
                'These are showing the last values this device saw. '
                '${state.error}',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
