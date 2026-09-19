import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/notification_history_model.dart';
import '../providers/notification_history_provider.dart';

/// Everything the app has told you, newest first.
class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends ConsumerState<NotificationHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationHistoryProvider.notifier).loadNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(notificationHistoryProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(notificationHistoryProvider.notifier).refresh();
  }

  void _handleTap(NotificationHistoryModel notification) {
    if (!notification.isRead) {
      ref.read(notificationHistoryProvider.notifier).markAsRead(notification.id);
    }

    switch (notification.type) {
      case 'trip_invite':
      case 'invite_expiring':
        final inviteCode = notification.data?['invite_code'];
        if (inviteCode != null) {
          context.push('${AppRoutes.acceptInvite}/$inviteCode');
        }
      case 'invite_accepted':
      case 'invite_declined':
      case 'share_revoked':
      case 'permission_changed':
      case 'memory_added':
      case 'document_added':
      case 'activity_added':
      case 'expense_added':
      case 'trip_reminder':
        final tripId = notification.relatedTripId;
        if (tripId != null) context.push('${AppRoutes.tripDetail}/$tripId');
      case 'achievement_earned':
        context.push(AppRoutes.achievements);
      default:
        // Nothing to open for a type this build does not know about.
        break;
    }
  }

  Future<void> _handleDelete(NotificationHistoryModel notification) async {
    HapticFeedback.selectionClick();
    final ok = await ref
        .read(notificationHistoryProvider.notifier)
        .deleteNotification(notification.id);
    if (!ok && mounted) {
      showOdysseyMessage(context, 'That one would not clear. Try again.');
    }
  }

  Future<void> _handleMarkAllRead() async {
    HapticFeedback.lightImpact();
    final ok = await ref
        .read(notificationHistoryProvider.notifier)
        .markAllAsRead();
    if (!ok && mounted) {
      showOdysseyMessage(context, 'Could not mark those as read.');
    }
  }

  Future<void> _handleClearAll() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Clear all',
      body: const ['This removes every notification from the list.'],
      confirmLabel: 'Clear all',
    );
    if (!confirmed || !mounted) return;

    final ok = await ref
        .read(notificationHistoryProvider.notifier)
        .deleteAllNotifications();
    if (!ok && mounted) {
      showOdysseyMessage(context, 'Could not clear those. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(notificationHistoryProvider);
    final unread = state.notifications.where((n) => !n.isRead).length;

    return OdysseyScaffold(
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: _handleRefresh,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(
              onBack: () => context.pop(),
              trailing: state.notifications.isEmpty
                  ? null
                  : CircleButton(
                      icon: Icons.more_horiz_rounded,
                      onPressed: () async {
                        final action = await showOdysseyPicker<String>(
                          context: context,
                          title: 'Notifications',
                          options: const ['Mark all as read', 'Clear all'],
                          labelOf: (value) => value,
                        );
                        if (!mounted || action == null) return;
                        if (action == 'Clear all') {
                          await _handleClearAll();
                        } else {
                          await _handleMarkAllRead();
                        }
                      },
                      semanticLabel: 'Notification options',
                    ),
            ),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Notifications',
              style: AppTypography.screenTitle.copyWith(color: t.ink),
            ),
            if (unread > 0) ...[
              const SizedBox(height: AppSizes.space8),
              Text(
                '$unread unread',
                style: AppTypography.meta.copyWith(color: t.limeText),
              ),
            ],
            const SizedBox(height: AppSizes.space20),

            if (state.isLoading && state.notifications.isEmpty)
              const Column(
                children: [
                  Skeleton.row(),
                  SizedBox(height: AppSizes.space10),
                  Skeleton.row(),
                ],
              )
            else if (state.error != null && state.notifications.isEmpty)
              OdysseyErrorState(
                message: state.error!,
                onRetry: _handleRefresh,
              )
            else if (state.notifications.isEmpty)
              const OdysseyEmptyState(
                message: 'Nothing yet. Reminders and invites land here.',
              )
            else
              for (final group in state.groupedByDate) ...[
                EyebrowLabel(group.label),
                const SizedBox(height: AppSizes.space12),
                for (final notification in group.notifications) ...[
                  _NotificationRow(
                    notification: notification,
                    onTap: () => _handleTap(notification),
                    onDelete: () => _handleDelete(notification),
                  ),
                  const SizedBox(height: AppSizes.space10),
                ],
                const SizedBox(height: AppSizes.space14),
              ],

            if (state.isLoadingMore) const Skeleton.row(),
          ],
        ),
      ),
    );
  }
}

/// One notification. Unread carries a lime dot rather than a tinted card —
/// the list is long, and tinting every unread row would flood the screen.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationHistoryModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final unread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSizes.space20),
          child: Text(
            'Clear',
            style: AppTypography.caption.copyWith(color: t.ink3),
          ),
        ),
      ),
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusRow),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(AppSizes.radiusRow),
            border: Border.all(color: t.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: unread ? t.action : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.rowTitle.copyWith(
                        color: unread ? t.ink : t.ink2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: AppTypography.rowMeta.copyWith(color: t.ink3),
                      maxLines: 3,
                    ),
                    if (notification.relatedTripTitle != null) ...[
                      const SizedBox(height: AppSizes.space8),
                      MonoTag(notification.relatedTripTitle!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
