import 'package:flutter/foundation.dart';

/// Product IDs for Odyssey subscription plans.
/// Must match the IDs configured in App Store Connect and Google Play Console.
class ProductIds {
  static const String monthlySubscription = 'odyssey_premium_monthly';
  static const String yearlySubscription = 'odyssey_premium_yearly';
  static const String lifetimePurchase = 'odyssey_premium_lifetime';

  static const Set<String> all = {
    monthlySubscription,
    yearlySubscription,
    lifetimePurchase,
  };

  static const Set<String> subscriptions = {
    monthlySubscription,
    yearlySubscription,
  };

  // Google Play test product IDs
  static const String testPurchased = 'android.test.purchased';
  static const String testCanceled = 'android.test.canceled';
  static const String testRefunded = 'android.test.refunded';
  static const String testUnavailable = 'android.test.item_unavailable';
}

/// Billing configuration for in-app purchases.
class BillingConfig {
  // Environment
  static const bool isTestMode = bool.fromEnvironment(
    'BILLING_TEST_MODE',
    defaultValue: false,
  );

  static const String packageName = 'com.pranta.odyssey';

  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration purchaseTimeout = Duration(minutes: 5);

  // Server verification
  static const bool enableServerVerification = true;
  static const Duration verificationTimeout = Duration(seconds: 30);

  // Grace period (must match backend GRACE_PERIOD_DAYS)
  static const Duration subscriptionGracePeriod = Duration(days: 3);

  // Static pricing fallbacks (USD) — used when store prices are unavailable
  static const Map<String, double> pricing = {
    ProductIds.monthlySubscription: 2.99,
    ProductIds.yearlySubscription: 24.99,
    ProductIds.lifetimePurchase: 49.99,
  };

  /// Returns product IDs based on environment.
  /// Release builds always use real products.
  /// Debug builds respect the test mode flag.
  static Set<String> getProductIds() {
    if (kReleaseMode) return ProductIds.all;
    if (isTestMode) return {ProductIds.testPurchased};
    return ProductIds.all;
  }

  /// Returns the plan name for a product ID.
  static String getPlanFromProductId(String productId) {
    return switch (productId) {
      ProductIds.monthlySubscription => 'monthly',
      ProductIds.yearlySubscription => 'yearly',
      ProductIds.lifetimePurchase => 'lifetime',
      _ => 'unknown',
    };
  }

  /// Whether the product is a recurring subscription (vs one-time purchase).
  static bool isSubscription(String productId) {
    return ProductIds.subscriptions.contains(productId);
  }

  /// Get the fallback price string for a product.
  static String getFallbackPrice(String productId) {
    final price = pricing[productId];
    return price != null ? '\$${price.toStringAsFixed(2)}' : '?';
  }
}
