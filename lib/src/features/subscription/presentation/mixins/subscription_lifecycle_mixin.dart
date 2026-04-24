import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/logger_service.dart';
import '../providers/subscription_provider.dart';

/// Mixin that refreshes subscription status when the app resumes from background.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with WidgetsBindingObserver, SubscriptionLifecycleMixin {
///   // Your code here
/// }
/// ```
///
/// The mixin automatically:
/// - Registers as a WidgetsBindingObserver in initState
/// - Removes observer in dispose
/// - Throttles refresh to max once per 5 minutes
mixin SubscriptionLifecycleMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 5);

  DateTime? _lastSubscriptionRefresh;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (_isRefreshing) return;

    if (_lastSubscriptionRefresh != null) {
      final elapsed = DateTime.now().difference(_lastSubscriptionRefresh!);
      if (elapsed < _refreshInterval) {
        AppLogger.debug(
          'Subscription refresh throttled: ${elapsed.inSeconds}s since last '
          '(min: ${_refreshInterval.inSeconds}s)',
        );
        return;
      }
    }

    _isRefreshing = true;
    _lastSubscriptionRefresh = DateTime.now();

    try {
      AppLogger.debug('Refreshing subscription status on app resume...');
      await ref.read(subscriptionProvider.notifier).refresh();
    } catch (e) {
      AppLogger.error('Failed to refresh subscription on resume: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manually trigger a subscription refresh, respecting the throttle interval.
  Future<bool> refreshSubscriptionIfNeeded() async {
    if (_isRefreshing) return false;

    if (_lastSubscriptionRefresh != null) {
      final elapsed = DateTime.now().difference(_lastSubscriptionRefresh!);
      if (elapsed < _refreshInterval) return false;
    }

    _isRefreshing = true;
    _lastSubscriptionRefresh = DateTime.now();

    try {
      await ref.read(subscriptionProvider.notifier).refresh();
      return true;
    } catch (e) {
      AppLogger.error('Failed to refresh subscription: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Force a subscription refresh, ignoring the throttle interval.
  Future<void> forceRefreshSubscription() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _lastSubscriptionRefresh = DateTime.now();

    try {
      await ref.read(subscriptionProvider.notifier).refresh();
    } catch (e) {
      AppLogger.error('Failed to force refresh subscription: $e');
    } finally {
      _isRefreshing = false;
    }
  }
}
