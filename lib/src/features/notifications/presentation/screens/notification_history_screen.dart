import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/empty_state.dart';
import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../core/router/app_router.dart';
import '../providers/notification_history_provider.dart';
import '../widgets/notification_item.dart';
import '../../data/models/notification_history_model.dart';

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

    // Load notifications when screen opens
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

  void _handleNotificationTap(NotificationHistoryModel notification) {
    // Mark as read
    if (!notification.isRead) {
      ref.read(notificationHistoryProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (notification.type) {
      case 'trip_invite':
      case 'invite_expiring':
        final inviteCode = notification.data?['invite_code'];
        if (inviteCode != null) {
          context.push('${AppRoutes.acceptInvite}/$inviteCode');
        }
        break;
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
        if (tripId != null) {
          context.push('${AppRoutes.tripDetail}/$tripId');
        }
        break;
      case 'achievement_earned':
        context.push(AppRoutes.achievements);
        break;
      default:
        // Unknown notification type, do nothing
        break;
    }
  }

  void _handleDeleteNotification(String notificationId) {
    ref.read(notificationHistoryProvider.notifier).deleteNotification(notificationId);

    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        backgroundColor: colorScheme.onSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: AppColors.sunnyYellow,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _handleMarkAllAsRead() async {
    HapticFeedback.mediumImpact();

    final state = ref.read(notificationHistoryProvider);
    if (state.unreadCount == 0) return;

    await ref.read(notificationHistoryProvider.notifier).markAllAsRead();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: AppSizes.space12),
              Text('All notifications marked as read'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(notificationHistoryProvider);

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
          'Notifications',
          style: AppTypography.titleLarge.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: _handleMarkAllAsRead,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 20,
                color: AppColors.skyBlue,
              ),
              label: Text(
                'Mark all read',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: AppSizes.space8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.sunnyYellow,
        backgroundColor: colorScheme.surface,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationHistoryState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: BouncingDotsLoader(),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: ErrorState(
          message: state.error!,
          onRetry: _handleRefresh,
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return _buildNotificationsList(state);
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.space24),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.skyBlue,
                ),
              ),
              const SizedBox(height: AppSizes.space24),
              Text(
                'No notifications yet',
                style: AppTypography.headlineSmall.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.space32),
                child: Text(
                  "When you receive notifications about trips, shares, and achievements, they'll appear here.",
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsList(NotificationHistoryState state) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space16,
        vertical: AppSizes.space8,
      ),
      itemCount: state.notifications.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index == state.notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.space24),
            child: Center(child: BouncingDotsLoader()),
          );
        }

        final notification = state.notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.space12),
          child: NotificationItem(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onDelete: () => _handleDeleteNotification(notification.id),
            onMarkAsRead: notification.isRead
                ? null
                : () => ref
                    .read(notificationHistoryProvider.notifier)
                    .markAsRead(notification.id),
          ),
        );
      },
    );
  }
}
