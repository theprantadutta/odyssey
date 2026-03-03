import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/notification_history_model.dart';
import '../../data/repositories/notification_history_repository.dart';

part 'notification_history_provider.g.dart';

/// A group of notifications with a date label
class NotificationGroup {
  final String label;
  final List<NotificationHistoryModel> notifications;

  const NotificationGroup({required this.label, required this.notifications});
}

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

  /// Group notifications by date buckets
  List<NotificationGroup> get groupedByDate {
    if (notifications.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayList = <NotificationHistoryModel>[];
    final yesterdayList = <NotificationHistoryModel>[];
    final thisWeekList = <NotificationHistoryModel>[];
    final earlierList = <NotificationHistoryModel>[];

    for (final n in notifications) {
      final date = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (date.isAtSameMomentAs(today) || date.isAfter(today)) {
        todayList.add(n);
      } else if (date.isAtSameMomentAs(yesterday)) {
        yesterdayList.add(n);
      } else if (date.isAfter(weekAgo)) {
        thisWeekList.add(n);
      } else {
        earlierList.add(n);
      }
    }

    final groups = <NotificationGroup>[];
    if (todayList.isNotEmpty) {
      groups.add(NotificationGroup(label: 'Today', notifications: todayList));
    }
    if (yesterdayList.isNotEmpty) {
      groups.add(NotificationGroup(label: 'Yesterday', notifications: yesterdayList));
    }
    if (thisWeekList.isNotEmpty) {
      groups.add(NotificationGroup(label: 'This Week', notifications: thisWeekList));
    }
    if (earlierList.isNotEmpty) {
      groups.add(NotificationGroup(label: 'Earlier', notifications: earlierList));
    }

    return groups;
  }

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
  /// Returns true on success, false on failure (for UI error feedback)
  Future<bool> markAsRead(String notificationId) async {
    // Optimistic update
    final previousState = state;
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
    ref.read(unreadNotificationCountProvider.notifier).setCount(newUnreadCount);

    try {
      final success = await _repository.markAsRead(notificationId);
      if (!success) {
        // Rollback on failure
        state = previousState;
        ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
        return false;
      }
      return true;
    } catch (e) {
      // Rollback on error
      state = previousState;
      ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
      return false;
    }
  }

  /// Mark all notifications as read
  /// Returns true on success, false on failure
  Future<bool> markAllAsRead() async {
    // Optimistic update
    final previousState = state;
    final updatedNotifications = state.notifications
        .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    );
    ref.read(unreadNotificationCountProvider.notifier).setCount(0);

    try {
      await _repository.markAllAsRead();
      return true;
    } catch (e) {
      // Rollback on error
      state = previousState;
      ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
      return false;
    }
  }

  /// Delete a notification
  /// Returns true on success, false on failure
  Future<bool> deleteNotification(String notificationId) async {
    // Optimistic update
    final previousState = state;
    final deletedNotification = state.notifications
        .where((n) => n.id == notificationId)
        .firstOrNull;

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
    ref.read(unreadNotificationCountProvider.notifier).setCount(newUnreadCount);

    try {
      final success = await _repository.deleteNotification(notificationId);
      if (!success) {
        // Rollback on failure
        state = previousState;
        ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
        return false;
      }
      return true;
    } catch (e) {
      // Rollback on error
      state = previousState;
      ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
      return false;
    }
  }

  /// Delete all notifications for the current user
  /// Returns true on success, false on failure
  Future<bool> deleteAllNotifications() async {
    final previousState = state;

    state = state.copyWith(
      notifications: [],
      total: 0,
      unreadCount: 0,
    );
    ref.read(unreadNotificationCountProvider.notifier).setCount(0);

    try {
      final success = await _repository.deleteAllNotifications();
      if (!success) {
        state = previousState;
        ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
        return false;
      }
      return true;
    } catch (e) {
      state = previousState;
      ref.read(unreadNotificationCountProvider.notifier).setCount(previousState.unreadCount);
      return false;
    }
  }
}

/// Unread notification count provider (for badge display)
/// Uses nullable int: null = loading, 0 = no unread, >0 = count
/// This is a separate provider for efficiency - we can update it independently
@Riverpod(keepAlive: true)
class UnreadNotificationCount extends _$UnreadNotificationCount {
  @override
  int? build() {
    // Initially fetch the count - return null while loading
    _fetchCount();
    return null;
  }

  Future<void> _fetchCount() async {
    try {
      final repository = ref.read(notificationHistoryRepositoryProvider);
      final count = await repository.getUnreadCount();
      state = count;
    } catch (e) {
      // Set to 0 on error to avoid perpetual loading state
      state ??= 0;
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
    state = (state ?? 0) + 1;
  }

  /// Decrement count (e.g., when a notification is read)
  void decrement() {
    if (state != null && state! > 0) {
      state = state! - 1;
    }
  }
}
