import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/notification_history_model.dart';

/// Widget to display a single notification item
class NotificationItem extends StatelessWidget {
  final NotificationHistoryModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMarkAsRead;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      confirmDismiss: (direction) async {
        HapticFeedback.lightImpact();
        return true;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.space24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.space16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? colorScheme.surface
                : AppColors.skyBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: notification.isRead
                  ? theme.scaffoldBackgroundColor
                  : AppColors.skyBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              _buildNotificationIcon(),
              const SizedBox(width: AppSizes.space12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.labelLarge.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Unread indicator
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: AppSizes.space8),
                            decoration: const BoxDecoration(
                              color: AppColors.skyBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space4),
                    // Body
                    Text(
                      notification.body,
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.space8),
                    // Metadata row
                    Row(
                      children: [
                        // Related trip/user info
                        if (notification.relatedTripTitle != null) ...[
                          Icon(
                            Icons.flight_takeoff_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notification.relatedTripTitle!,
                              style: AppTypography.labelSmall.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSizes.space8),
                        ] else if (notification.relatedUserName != null) ...[
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notification.relatedUserName!,
                              style: AppTypography.labelSmall.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSizes.space8),
                        ] else
                          const Spacer(),
                        // Time ago
                        Text(
                          _formatTimeAgo(notification.createdAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);

    return Container(
      padding: const EdgeInsets.all(AppSizes.space8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 22,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'trip_invite':
        return Icons.mail_outline_rounded;
      case 'invite_accepted':
        return Icons.check_circle_outline_rounded;
      case 'invite_declined':
        return Icons.cancel_outlined;
      case 'invite_expiring':
        return Icons.access_time_rounded;
      case 'share_revoked':
        return Icons.person_remove_outlined;
      case 'permission_changed':
        return Icons.security_rounded;
      case 'memory_added':
        return Icons.photo_library_outlined;
      case 'document_added':
        return Icons.description_outlined;
      case 'activity_added':
        return Icons.event_outlined;
      case 'expense_added':
        return Icons.receipt_long_outlined;
      case 'trip_reminder':
        return Icons.notifications_active_outlined;
      case 'achievement_earned':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'trip_invite':
        return AppColors.skyBlue;
      case 'invite_accepted':
        return AppColors.success;
      case 'invite_declined':
        return AppColors.error;
      case 'invite_expiring':
        return AppColors.sunnyYellow;
      case 'share_revoked':
        return AppColors.coralBurst;
      case 'permission_changed':
        return AppColors.lavenderDream;
      case 'memory_added':
        return AppColors.mintGreen;
      case 'document_added':
        return AppColors.oceanTeal;
      case 'activity_added':
        return AppColors.skyBlue;
      case 'expense_added':
        return AppColors.goldenGlow;
      case 'trip_reminder':
        return AppColors.coralBurst;
      case 'achievement_earned':
        return AppColors.sunnyYellow;
      default:
        return AppColors.slate;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
