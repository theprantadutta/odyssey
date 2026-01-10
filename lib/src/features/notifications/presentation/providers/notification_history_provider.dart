import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/notification_history_model.dart';
import '../../data/repositories/notification_history_repository.dart';

part 'notification_history_provider.g.dart';

/// Notification history state with pagination support
class NotificationHistoryState {
  final List<NotificationHistoryModel> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int totalPages;
  final int total;
  final int unreadCount;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const NotificationHistoryState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 0,
    this.total = 0,
    this.unreadCount = 0,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  });

  /// Check if we can load more notifications
  bool get canLoadMore => hasNextPage && !isLoadingMore;

  NotificationHistoryState copyWith({
    List<NotificationHistoryModel>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    int? totalPages,
    int? total,
    int? unreadCount,
    bool? hasNextPage,
    bool? hasPreviousPage,
  }) {
    return NotificationHistoryState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      unreadCount: unreadCount ?? this.unreadCount,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
    );
  }
}

/// Notification history repository provider
@Riverpod(keepAlive: true)
NotificationHistoryRepository notificationHistoryRepository(Ref ref) {
  return NotificationHistoryRepository();
}

/// Notification history provider with pagination
@Riverpod(keepAlive: true)
class NotificationHistory extends _$NotificationHistory {
  NotificationHistoryRepository get _repository =>
      ref.read(notificationHistoryRepositoryProvider);

  @override
  NotificationHistoryState build() {
    return const NotificationHistoryState();
  }

  /// Load notifications (initial load or refresh)
  Future<void> loadNotifications({int page = 1}) async {
    if (page == 1) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _repository.getNotifications(page: page);

      state = state.copyWith(
        notifications: response.notifications,
        currentPage: response.page,
        totalPages: response.totalPages,
        total: response.total,
        unreadCount: response.unreadCount,
        hasNextPage: response.hasNextPage,
        hasPreviousPage: response.hasPreviousPage,
        isLoading: false,
      );

      // Update the unread count provider
      ref.read(unreadNotificationCountProvider.notifier).setCount(response.unreadCount);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more notifications (infinite scroll)
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getNotifications(page: nextPage);

      state = state.copyWith(
        notifications: [...state.notifications, ...response.notifications],
        currentPage: response.page,
        totalPages: response.totalPages,
        total: response.total,
        unreadCount: response.unreadCount,
        hasNextPage: response.hasNextPage,
        hasPreviousPage: response.hasPreviousPage,
        isLoadingMore: false,
      );

      // Update the unread count provider
      ref.read(unreadNotificationCountProvider.notifier).setCount(response.unreadCount);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Refresh notifications (pull-to-refresh)
  Future<void> refresh() async {
    await loadNotifications(page: 1);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _repository.markAsRead(notificationId);
      if (success) {
        // Update local state
        final updatedNotifications = state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true, readAt: DateTime.now());
          }
          return n;
        }).toList();

        final newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;

        state = state.copyWith(
          notifications: updatedNotifications,
          unreadCount: newUnreadCount,
        );

        // Update the unread count provider
        ref.read(unreadNotificationCountProvider.notifier).setCount(newUnreadCount);
      }
    } catch (e) {
      // Silent failure - the notification will still be marked as read on next refresh
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();

      // Update local state
      final updatedNotifications = state.notifications
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );

      // Update the unread count provider
      ref.read(unreadNotificationCountProvider.notifier).setCount(0);
    } catch (e) {
      // Silent failure - will sync on next refresh
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final success = await _repository.deleteNotification(notificationId);
      if (success) {
        // Find the notification to check if it was unread
        final deletedNotification = state.notifications
            .where((n) => n.id == notificationId)
            .firstOrNull;

        // Update local state
        final updatedNotifications = state.notifications
            .where((n) => n.id != notificationId)
            .toList();

        int newUnreadCount = state.unreadCount;
        if (deletedNotification != null && !deletedNotification.isRead) {
          newUnreadCount = state.unreadCount > 0 ? state.unreadCount - 1 : 0;
        }

        state = state.copyWith(
          notifications: updatedNotifications,
          total: state.total > 0 ? state.total - 1 : 0,
          unreadCount: newUnreadCount,
        );

        // Update the unread count provider
        ref.read(unreadNotificationCountProvider.notifier).setCount(newUnreadCount);
      }
    } catch (e) {
      // Silent failure - will sync on next refresh
    }
  }
}

/// Unread notification count provider (for badge display)
/// This is a separate provider for efficiency - we can update it independently
@Riverpod(keepAlive: true)
class UnreadNotificationCount extends _$UnreadNotificationCount {
  @override
  int build() {
    // Initially fetch the count
    _fetchCount();
    return 0;
  }

  Future<void> _fetchCount() async {
    try {
      final repository = ref.read(notificationHistoryRepositoryProvider);
      final count = await repository.getUnreadCount();
      state = count;
    } catch (e) {
      // Keep the current count on error
    }
  }

  /// Set the count directly (called from NotificationHistory provider)
  void setCount(int count) {
    state = count;
  }

  /// Refresh the count from the server
  Future<void> refresh() async {
    await _fetchCount();
  }

  /// Increment count (e.g., when a new notification arrives)
  void increment() {
    state = state + 1;
  }

  /// Decrement count (e.g., when a notification is read)
  void decrement() {
    if (state > 0) {
      state = state - 1;
    }
  }
}
