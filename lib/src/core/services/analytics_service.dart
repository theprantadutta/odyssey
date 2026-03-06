import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:odyssey/src/core/services/logger_service.dart';

// ─────────────────────────────────────────────────────────────────
// Abstract Analytics Client
// ─────────────────────────────────────────────────────────────────

abstract class AnalyticsClient {
  // Auth
  Future<void> trackIntroSeen();
  Future<void> trackTermsAccepted();
  Future<void> trackSignUp({required String method});
  Future<void> trackLogin({required String method});
  Future<void> trackOnboardingCompleted({required bool addedDemoTrips});
  Future<void> trackAccountLinked();
  Future<void> trackLogout();

  // Trips
  Future<void> trackTripCreated({required String source});
  Future<void> trackTripUpdated();
  Future<void> trackTripDeleted();
  Future<void> trackTripSearch({required bool hasResults});
  Future<void> trackTripFilterApplied({required String filterType});

  // Content
  Future<void> trackActivityCreated({required String category});
  Future<void> trackExpenseCreated({
    required String category,
    required String currency,
  });
  Future<void> trackMemoryUploaded({required String mediaType});
  Future<void> trackDocumentUploaded({required String type});
  Future<void> trackPackingItemCreated({required String category});
  Future<void> trackPackingItemToggled({required bool packed});

  // Templates
  Future<void> trackTemplateCreated({required String source});
  Future<void> trackTemplateUsed({
    required String templateId,
    required bool isPublic,
  });
  Future<void> trackTemplateForked({required String templateId});
  Future<void> trackTemplateGallerySearched({required String category});

  // Sharing
  Future<void> trackTripShared({required String permission});
  Future<void> trackSharePermissionChanged({required String newPermission});
  Future<void> trackShareRevoked();
  Future<void> trackInviteAccepted();
  Future<void> trackInviteDeclined();

  // Subscription
  Future<void> trackPaywallShown({required String featureName});
  Future<void> trackPurchaseInitiated({required String plan});
  Future<void> trackPurchaseCompleted({required String plan});
  Future<void> trackPurchaseFailed({
    required String plan,
    required String error,
  });
  Future<void> trackRestoreInitiated();

  // Achievements
  Future<void> trackAchievementEarned({
    required String achievementId,
    required String type,
  });
  Future<void> trackAchievementsViewed();
  Future<void> trackLeaderboardViewed();

  // Statistics
  Future<void> trackStatisticsViewed();
  Future<void> trackYearInReviewViewed({required int year});

  // Settings
  Future<void> trackDarkModeToggled({required bool enabled});
  Future<void> trackNotificationPermission({required bool granted});

  // User properties
  Future<void> setUserId(String? id);
  Future<void> setUserProperty({required String name, required String? value});
}

// ─────────────────────────────────────────────────────────────────
// Firebase Analytics Client
// ─────────────────────────────────────────────────────────────────

class FirebaseAnalyticsClient implements AnalyticsClient {
  FirebaseAnalyticsClient(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> _safeLog(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      AppLogger.error('Firebase Analytics error', e, st);
    }
  }

  // Auth
  @override
  Future<void> trackIntroSeen() =>
      _safeLog(() => _analytics.logEvent(name: 'intro_seen'));

  @override
  Future<void> trackTermsAccepted() =>
      _safeLog(() => _analytics.logEvent(name: 'terms_accepted'));

  @override
  Future<void> trackSignUp({required String method}) =>
      _safeLog(() => _analytics.logSignUp(signUpMethod: method));

  @override
  Future<void> trackLogin({required String method}) =>
      _safeLog(() => _analytics.logLogin(loginMethod: method));

  @override
  Future<void> trackOnboardingCompleted({required bool addedDemoTrips}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'onboarding_completed',
        parameters: {'added_demo_trips': addedDemoTrips},
      ));

  @override
  Future<void> trackAccountLinked() =>
      _safeLog(() => _analytics.logEvent(name: 'account_linked'));

  @override
  Future<void> trackLogout() =>
      _safeLog(() => _analytics.logEvent(name: 'logout'));

  // Trips
  @override
  Future<void> trackTripCreated({required String source}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'trip_created',
        parameters: {'source': source},
      ));

  @override
  Future<void> trackTripUpdated() =>
      _safeLog(() => _analytics.logEvent(name: 'trip_updated'));

  @override
  Future<void> trackTripDeleted() =>
      _safeLog(() => _analytics.logEvent(name: 'trip_deleted'));

  @override
  Future<void> trackTripSearch({required bool hasResults}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'trip_search',
        parameters: {'has_results': hasResults},
      ));

  @override
  Future<void> trackTripFilterApplied({required String filterType}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'trip_filter_applied',
        parameters: {'filter_type': filterType},
      ));

  // Content
  @override
  Future<void> trackActivityCreated({required String category}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'activity_created',
        parameters: {'category': category},
      ));

  @override
  Future<void> trackExpenseCreated({
    required String category,
    required String currency,
  }) =>
      _safeLog(() => _analytics.logEvent(
        name: 'expense_created',
        parameters: {'category': category, 'currency': currency},
      ));

  @override
  Future<void> trackMemoryUploaded({required String mediaType}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'memory_uploaded',
        parameters: {'media_type': mediaType},
      ));

  @override
  Future<void> trackDocumentUploaded({required String type}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'document_uploaded',
        parameters: {'type': type},
      ));

  @override
  Future<void> trackPackingItemCreated({required String category}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'packing_item_created',
        parameters: {'category': category},
      ));

  @override
  Future<void> trackPackingItemToggled({required bool packed}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'packing_item_toggled',
        parameters: {'packed': packed},
      ));

  // Templates
  @override
  Future<void> trackTemplateCreated({required String source}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'template_created',
        parameters: {'source': source},
      ));

  @override
  Future<void> trackTemplateUsed({
    required String templateId,
    required bool isPublic,
  }) =>
      _safeLog(() => _analytics.logEvent(
        name: 'template_used',
        parameters: {'template_id': templateId, 'is_public': isPublic},
      ));

  @override
  Future<void> trackTemplateForked({required String templateId}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'template_forked',
        parameters: {'template_id': templateId},
      ));

  @override
  Future<void> trackTemplateGallerySearched({required String category}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'template_gallery_searched',
        parameters: {'category': category},
      ));

  // Sharing
  @override
  Future<void> trackTripShared({required String permission}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'trip_shared',
        parameters: {'permission': permission},
      ));

  @override
  Future<void> trackSharePermissionChanged({required String newPermission}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'share_permission_changed',
        parameters: {'new_permission': newPermission},
      ));

  @override
  Future<void> trackShareRevoked() =>
      _safeLog(() => _analytics.logEvent(name: 'share_revoked'));

  @override
  Future<void> trackInviteAccepted() =>
      _safeLog(() => _analytics.logEvent(name: 'invite_accepted'));

  @override
  Future<void> trackInviteDeclined() =>
      _safeLog(() => _analytics.logEvent(name: 'invite_declined'));

  // Subscription
  @override
  Future<void> trackPaywallShown({required String featureName}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'paywall_shown',
        parameters: {'feature_name': featureName},
      ));

  @override
  Future<void> trackPurchaseInitiated({required String plan}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'purchase_initiated',
        parameters: {'plan': plan},
      ));

  @override
  Future<void> trackPurchaseCompleted({required String plan}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'purchase_completed',
        parameters: {'plan': plan},
      ));

  @override
  Future<void> trackPurchaseFailed({
    required String plan,
    required String error,
  }) =>
      _safeLog(() => _analytics.logEvent(
        name: 'purchase_failed',
        parameters: {'plan': plan, 'error': error},
      ));

  @override
  Future<void> trackRestoreInitiated() =>
      _safeLog(() => _analytics.logEvent(name: 'restore_initiated'));

  // Achievements
  @override
  Future<void> trackAchievementEarned({
    required String achievementId,
    required String type,
  }) =>
      _safeLog(() => _analytics.logEvent(
        name: 'achievement_earned',
        parameters: {'achievement_id': achievementId, 'type': type},
      ));

  @override
  Future<void> trackAchievementsViewed() =>
      _safeLog(() => _analytics.logEvent(name: 'achievements_viewed'));

  @override
  Future<void> trackLeaderboardViewed() =>
      _safeLog(() => _analytics.logEvent(name: 'leaderboard_viewed'));

  // Statistics
  @override
  Future<void> trackStatisticsViewed() =>
      _safeLog(() => _analytics.logEvent(name: 'statistics_viewed'));

  @override
  Future<void> trackYearInReviewViewed({required int year}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'year_in_review_viewed',
        parameters: {'year': year},
      ));

  // Settings
  @override
  Future<void> trackDarkModeToggled({required bool enabled}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'dark_mode_toggled',
        parameters: {'enabled': enabled},
      ));

  @override
  Future<void> trackNotificationPermission({required bool granted}) =>
      _safeLog(() => _analytics.logEvent(
        name: 'notification_permission',
        parameters: {'granted': granted},
      ));

  // User properties
  @override
  Future<void> setUserId(String? id) =>
      _safeLog(() => _analytics.setUserId(id: id));

  @override
  Future<void> setUserProperty({required String name, required String? value}) =>
      _safeLog(() => _analytics.setUserProperty(name: name, value: value));
}

// ─────────────────────────────────────────────────────────────────
// Logger Analytics Client (debug only)
// ─────────────────────────────────────────────────────────────────

class LoggerAnalyticsClient implements AnalyticsClient {
  void _log(String event, [Map<String, Object?>? params]) {
    final paramStr = params != null && params.isNotEmpty ? ' $params' : '';
    AppLogger.info('ANALYTICS: $event$paramStr');
  }

  // Auth
  @override
  Future<void> trackIntroSeen() async => _log('intro_seen');

  @override
  Future<void> trackTermsAccepted() async => _log('terms_accepted');

  @override
  Future<void> trackSignUp({required String method}) async =>
      _log('sign_up', {'method': method});

  @override
  Future<void> trackLogin({required String method}) async =>
      _log('login', {'method': method});

  @override
  Future<void> trackOnboardingCompleted({required bool addedDemoTrips}) async =>
      _log('onboarding_completed', {'added_demo_trips': addedDemoTrips});

  @override
  Future<void> trackAccountLinked() async => _log('account_linked');

  @override
  Future<void> trackLogout() async => _log('logout');

  // Trips
  @override
  Future<void> trackTripCreated({required String source}) async =>
      _log('trip_created', {'source': source});

  @override
  Future<void> trackTripUpdated() async => _log('trip_updated');

  @override
  Future<void> trackTripDeleted() async => _log('trip_deleted');

  @override
  Future<void> trackTripSearch({required bool hasResults}) async =>
      _log('trip_search', {'has_results': hasResults});

  @override
  Future<void> trackTripFilterApplied({required String filterType}) async =>
      _log('trip_filter_applied', {'filter_type': filterType});

  // Content
  @override
  Future<void> trackActivityCreated({required String category}) async =>
      _log('activity_created', {'category': category});

  @override
  Future<void> trackExpenseCreated({
    required String category,
    required String currency,
  }) async =>
      _log('expense_created', {'category': category, 'currency': currency});

  @override
  Future<void> trackMemoryUploaded({required String mediaType}) async =>
      _log('memory_uploaded', {'media_type': mediaType});

  @override
  Future<void> trackDocumentUploaded({required String type}) async =>
      _log('document_uploaded', {'type': type});

  @override
  Future<void> trackPackingItemCreated({required String category}) async =>
      _log('packing_item_created', {'category': category});

  @override
  Future<void> trackPackingItemToggled({required bool packed}) async =>
      _log('packing_item_toggled', {'packed': packed});

  // Templates
  @override
  Future<void> trackTemplateCreated({required String source}) async =>
      _log('template_created', {'source': source});

  @override
  Future<void> trackTemplateUsed({
    required String templateId,
    required bool isPublic,
  }) async =>
      _log('template_used', {'template_id': templateId, 'is_public': isPublic});

  @override
  Future<void> trackTemplateForked({required String templateId}) async =>
      _log('template_forked', {'template_id': templateId});

  @override
  Future<void> trackTemplateGallerySearched({required String category}) async =>
      _log('template_gallery_searched', {'category': category});

  // Sharing
  @override
  Future<void> trackTripShared({required String permission}) async =>
      _log('trip_shared', {'permission': permission});

  @override
  Future<void> trackSharePermissionChanged({
    required String newPermission,
  }) async =>
      _log('share_permission_changed', {'new_permission': newPermission});

  @override
  Future<void> trackShareRevoked() async => _log('share_revoked');

  @override
  Future<void> trackInviteAccepted() async => _log('invite_accepted');

  @override
  Future<void> trackInviteDeclined() async => _log('invite_declined');

  // Subscription
  @override
  Future<void> trackPaywallShown({required String featureName}) async =>
      _log('paywall_shown', {'feature_name': featureName});

  @override
  Future<void> trackPurchaseInitiated({required String plan}) async =>
      _log('purchase_initiated', {'plan': plan});

  @override
  Future<void> trackPurchaseCompleted({required String plan}) async =>
      _log('purchase_completed', {'plan': plan});

  @override
  Future<void> trackPurchaseFailed({
    required String plan,
    required String error,
  }) async =>
      _log('purchase_failed', {'plan': plan, 'error': error});

  @override
  Future<void> trackRestoreInitiated() async => _log('restore_initiated');

  // Achievements
  @override
  Future<void> trackAchievementEarned({
    required String achievementId,
    required String type,
  }) async =>
      _log('achievement_earned', {
        'achievement_id': achievementId,
        'type': type,
      });

  @override
  Future<void> trackAchievementsViewed() async =>
      _log('achievements_viewed');

  @override
  Future<void> trackLeaderboardViewed() async => _log('leaderboard_viewed');

  // Statistics
  @override
  Future<void> trackStatisticsViewed() async => _log('statistics_viewed');

  @override
  Future<void> trackYearInReviewViewed({required int year}) async =>
      _log('year_in_review_viewed', {'year': year});

  // Settings
  @override
  Future<void> trackDarkModeToggled({required bool enabled}) async =>
      _log('dark_mode_toggled', {'enabled': enabled});

  @override
  Future<void> trackNotificationPermission({required bool granted}) async =>
      _log('notification_permission', {'granted': granted});

  // User properties
  @override
  Future<void> setUserId(String? id) async =>
      _log('set_user_id', {'id': id});

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async =>
      _log('set_user_property', {'name': name, 'value': value});
}

// ─────────────────────────────────────────────────────────────────
// Analytics Facade
// ─────────────────────────────────────────────────────────────────

class AnalyticsFacade implements AnalyticsClient {
  AnalyticsFacade(this._clients);

  final List<AnalyticsClient> _clients;

  void _dispatch(Future<void> Function(AnalyticsClient c) action) {
    for (final client in _clients) {
      unawaited(
        action(client).catchError((Object e, StackTrace st) {
          AppLogger.error(
            'Analytics dispatch error for ${client.runtimeType}',
            e,
            st,
          );
        }),
      );
    }
  }

  // Auth
  @override
  Future<void> trackIntroSeen() async =>
      _dispatch((c) => c.trackIntroSeen());

  @override
  Future<void> trackTermsAccepted() async =>
      _dispatch((c) => c.trackTermsAccepted());

  @override
  Future<void> trackSignUp({required String method}) async =>
      _dispatch((c) => c.trackSignUp(method: method));

  @override
  Future<void> trackLogin({required String method}) async =>
      _dispatch((c) => c.trackLogin(method: method));

  @override
  Future<void> trackOnboardingCompleted({required bool addedDemoTrips}) async =>
      _dispatch((c) => c.trackOnboardingCompleted(addedDemoTrips: addedDemoTrips));

  @override
  Future<void> trackAccountLinked() async =>
      _dispatch((c) => c.trackAccountLinked());

  @override
  Future<void> trackLogout() async =>
      _dispatch((c) => c.trackLogout());

  // Trips
  @override
  Future<void> trackTripCreated({required String source}) async =>
      _dispatch((c) => c.trackTripCreated(source: source));

  @override
  Future<void> trackTripUpdated() async =>
      _dispatch((c) => c.trackTripUpdated());

  @override
  Future<void> trackTripDeleted() async =>
      _dispatch((c) => c.trackTripDeleted());

  @override
  Future<void> trackTripSearch({required bool hasResults}) async =>
      _dispatch((c) => c.trackTripSearch(hasResults: hasResults));

  @override
  Future<void> trackTripFilterApplied({required String filterType}) async =>
      _dispatch((c) => c.trackTripFilterApplied(filterType: filterType));

  // Content
  @override
  Future<void> trackActivityCreated({required String category}) async =>
      _dispatch((c) => c.trackActivityCreated(category: category));

  @override
  Future<void> trackExpenseCreated({
    required String category,
    required String currency,
  }) async =>
      _dispatch(
        (c) => c.trackExpenseCreated(category: category, currency: currency),
      );

  @override
  Future<void> trackMemoryUploaded({required String mediaType}) async =>
      _dispatch((c) => c.trackMemoryUploaded(mediaType: mediaType));

  @override
  Future<void> trackDocumentUploaded({required String type}) async =>
      _dispatch((c) => c.trackDocumentUploaded(type: type));

  @override
  Future<void> trackPackingItemCreated({required String category}) async =>
      _dispatch((c) => c.trackPackingItemCreated(category: category));

  @override
  Future<void> trackPackingItemToggled({required bool packed}) async =>
      _dispatch((c) => c.trackPackingItemToggled(packed: packed));

  // Templates
  @override
  Future<void> trackTemplateCreated({required String source}) async =>
      _dispatch((c) => c.trackTemplateCreated(source: source));

  @override
  Future<void> trackTemplateUsed({
    required String templateId,
    required bool isPublic,
  }) async =>
      _dispatch(
        (c) => c.trackTemplateUsed(templateId: templateId, isPublic: isPublic),
      );

  @override
  Future<void> trackTemplateForked({required String templateId}) async =>
      _dispatch((c) => c.trackTemplateForked(templateId: templateId));

  @override
  Future<void> trackTemplateGallerySearched({required String category}) async =>
      _dispatch((c) => c.trackTemplateGallerySearched(category: category));

  // Sharing
  @override
  Future<void> trackTripShared({required String permission}) async =>
      _dispatch((c) => c.trackTripShared(permission: permission));

  @override
  Future<void> trackSharePermissionChanged({
    required String newPermission,
  }) async =>
      _dispatch(
        (c) => c.trackSharePermissionChanged(newPermission: newPermission),
      );

  @override
  Future<void> trackShareRevoked() async =>
      _dispatch((c) => c.trackShareRevoked());

  @override
  Future<void> trackInviteAccepted() async =>
      _dispatch((c) => c.trackInviteAccepted());

  @override
  Future<void> trackInviteDeclined() async =>
      _dispatch((c) => c.trackInviteDeclined());

  // Subscription
  @override
  Future<void> trackPaywallShown({required String featureName}) async =>
      _dispatch((c) => c.trackPaywallShown(featureName: featureName));

  @override
  Future<void> trackPurchaseInitiated({required String plan}) async =>
      _dispatch((c) => c.trackPurchaseInitiated(plan: plan));

  @override
  Future<void> trackPurchaseCompleted({required String plan}) async =>
      _dispatch((c) => c.trackPurchaseCompleted(plan: plan));

  @override
  Future<void> trackPurchaseFailed({
    required String plan,
    required String error,
  }) async =>
      _dispatch((c) => c.trackPurchaseFailed(plan: plan, error: error));

  @override
  Future<void> trackRestoreInitiated() async =>
      _dispatch((c) => c.trackRestoreInitiated());

  // Achievements
  @override
  Future<void> trackAchievementEarned({
    required String achievementId,
    required String type,
  }) async =>
      _dispatch(
        (c) => c.trackAchievementEarned(
          achievementId: achievementId,
          type: type,
        ),
      );

  @override
  Future<void> trackAchievementsViewed() async =>
      _dispatch((c) => c.trackAchievementsViewed());

  @override
  Future<void> trackLeaderboardViewed() async =>
      _dispatch((c) => c.trackLeaderboardViewed());

  // Statistics
  @override
  Future<void> trackStatisticsViewed() async =>
      _dispatch((c) => c.trackStatisticsViewed());

  @override
  Future<void> trackYearInReviewViewed({required int year}) async =>
      _dispatch((c) => c.trackYearInReviewViewed(year: year));

  // Settings
  @override
  Future<void> trackDarkModeToggled({required bool enabled}) async =>
      _dispatch((c) => c.trackDarkModeToggled(enabled: enabled));

  @override
  Future<void> trackNotificationPermission({required bool granted}) async =>
      _dispatch((c) => c.trackNotificationPermission(granted: granted));

  // User properties
  @override
  Future<void> setUserId(String? id) async =>
      _dispatch((c) => c.setUserId(id));

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async =>
      _dispatch((c) => c.setUserProperty(name: name, value: value));
}
