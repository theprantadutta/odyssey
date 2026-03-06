import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/analytics_service.dart';

part 'analytics_provider.g.dart';

@Riverpod(keepAlive: true)
AnalyticsFacade analyticsService(Ref ref) {
  if (kDebugMode) {
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
  }

  final clients = <AnalyticsClient>[
    if (!kDebugMode) FirebaseAnalyticsClient(FirebaseAnalytics.instance),
    if (kDebugMode) LoggerAnalyticsClient(),
  ];
  return AnalyticsFacade(clients);
}
