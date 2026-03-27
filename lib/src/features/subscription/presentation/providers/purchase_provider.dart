import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/constants/billing_config.dart';
import '../../data/services/purchase_service.dart';
import 'subscription_provider.dart';

part 'purchase_provider.g.dart';

/// State for purchase operations
class PurchaseState {
  final bool isInitialized;
  final bool isAvailable;
  final bool isPurchasing;
  final String? activeProductId;
  final List<ProductDetails> products;
  final String? error;
  final String? successMessage;

  const PurchaseState({
    this.isInitialized = false,
    this.isAvailable = false,
    this.isPurchasing = false,
    this.activeProductId,
    this.products = const [],
    this.error,
    this.successMessage,
  });

  ProductDetails? get monthlyProduct =>
      products.where((p) => p.id == ProductIds.monthlySubscription).firstOrNull;

  ProductDetails? get yearlyProduct =>
      products.where((p) => p.id == ProductIds.yearlySubscription).firstOrNull;

  ProductDetails? get lifetimeProduct =>
      products.where((p) => p.id == ProductIds.lifetimePurchase).firstOrNull;

  PurchaseState copyWith({
    bool? isInitialized,
    bool? isAvailable,
    bool? isPurchasing,
    String? activeProductId,
    List<ProductDetails>? products,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearActiveProduct = false,
  }) {
    return PurchaseState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAvailable: isAvailable ?? this.isAvailable,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      activeProductId:
          clearActiveProduct ? null : (activeProductId ?? this.activeProductId),
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

/// Purchase state notifier provider
@Riverpod(keepAlive: true)
class Purchase extends _$Purchase {
  late final PurchaseService _purchaseService;

  @override
  PurchaseState build() {
    _purchaseService = PurchaseService();

    // Set up callbacks
    _purchaseService.onPurchaseComplete = _onPurchaseComplete;
    _purchaseService.onPurchaseError = _onPurchaseError;
    _purchaseService.onPurchasePending = _onPurchasePending;
    _purchaseService.onPurchaseRestored = _onPurchaseRestored;

    // Initialize on build
    _initialize();

    return const PurchaseState();
  }

  Future<void> _initialize() async {
    try {
      await _purchaseService.initialize();

      state = state.copyWith(
        isInitialized: true,
        isAvailable: _purchaseService.isAvailable,
        products: _purchaseService.products,
      );
    } catch (e) {
      AppLogger.error('Failed to initialize purchases: $e');
      state = state.copyWith(
        isInitialized: true,
        error: 'Failed to load store: $e',
      );
    }
  }

  String _planFromProductId(String? productId) {
    if (productId == null) return 'unknown';
    return BillingConfig.getPlanFromProductId(productId);
  }

  void _onPurchaseComplete(PurchaseResult result) {
    AppLogger.info('Purchase complete: ${result.productId}');
    unawaited(ref.read(analyticsServiceProvider).trackPurchaseCompleted(
          plan: _planFromProductId(result.productId),
        ));
    state = state.copyWith(
      isPurchasing: false,
      successMessage: 'Purchase successful! You are now a Premium member.',
      clearError: true,
      clearActiveProduct: true,
    );

    // Refresh subscription status
    ref.read(subscriptionProvider.notifier).refresh();
  }

  void _onPurchaseRestored(PurchaseResult result) {
    AppLogger.info('Purchase restored: ${result.productId}');
    state = state.copyWith(
      isPurchasing: false,
      successMessage: 'Purchases restored successfully!',
      clearError: true,
      clearActiveProduct: true,
    );

    ref.read(subscriptionProvider.notifier).refresh();
  }

  void _onPurchaseError(String error) {
    AppLogger.error('Purchase error: $error');
    unawaited(ref
        .read(analyticsServiceProvider)
        .trackPurchaseFailed(plan: 'unknown', error: error));
    state = state.copyWith(
      isPurchasing: false,
      error: error,
      clearSuccess: true,
      clearActiveProduct: true,
    );
  }

  void _onPurchasePending() {
    AppLogger.info('Purchase pending');
    state = state.copyWith(isPurchasing: true);
  }

  /// Purchase monthly subscription
  Future<void> purchaseMonthly() async {
    final product = state.monthlyProduct;
    if (product == null) {
      state = state.copyWith(error: 'Monthly subscription not available');
      return;
    }
    unawaited(
        ref.read(analyticsServiceProvider).trackPurchaseInitiated(plan: 'monthly'));
    await _purchase(product);
  }

  /// Purchase yearly subscription
  Future<void> purchaseYearly() async {
    final product = state.yearlyProduct;
    if (product == null) {
      state = state.copyWith(error: 'Yearly subscription not available');
      return;
    }
    unawaited(
        ref.read(analyticsServiceProvider).trackPurchaseInitiated(plan: 'yearly'));
    await _purchase(product);
  }

  /// Purchase lifetime
  Future<void> purchaseLifetime() async {
    final product = state.lifetimeProduct;
    if (product == null) {
      state = state.copyWith(error: 'Lifetime purchase not available');
      return;
    }
    unawaited(ref
        .read(analyticsServiceProvider)
        .trackPurchaseInitiated(plan: 'lifetime'));
    await _purchase(product);
  }

  /// Change to monthly subscription (upgrade/downgrade)
  Future<void> changeToMonthly() async {
    final product = state.monthlyProduct;
    if (product == null) {
      state = state.copyWith(error: 'Monthly subscription not available');
      return;
    }
    await _changeSubscription(product);
  }

  /// Change to yearly subscription (upgrade/downgrade)
  Future<void> changeToYearly() async {
    final product = state.yearlyProduct;
    if (product == null) {
      state = state.copyWith(error: 'Yearly subscription not available');
      return;
    }
    await _changeSubscription(product);
  }

  /// Change to lifetime (upgrade)
  Future<void> changeToLifetime() async {
    final product = state.lifetimeProduct;
    if (product == null) {
      state = state.copyWith(error: 'Lifetime purchase not available');
      return;
    }
    await _changeSubscription(product);
  }

  Future<void> _purchase(ProductDetails product) async {
    if (state.isPurchasing) return;

    state = state.copyWith(
      isPurchasing: true,
      activeProductId: product.id,
      clearError: true,
    );

    final result = await _purchaseService.purchase(product);

    if (!result.success) {
      state = state.copyWith(
        isPurchasing: false,
        error: result.errorMessage ?? 'Purchase failed',
        clearActiveProduct: true,
      );
    }
    // Success will be handled by the stream callback
  }

  Future<void> _changeSubscription(ProductDetails product) async {
    if (state.isPurchasing) return;

    state = state.copyWith(
      isPurchasing: true,
      activeProductId: product.id,
      clearError: true,
    );

    final result = await _purchaseService.changeSubscription(product);

    if (!result.success) {
      state = state.copyWith(
        isPurchasing: false,
        error: result.errorMessage ?? 'Subscription change failed',
        clearActiveProduct: true,
      );
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (state.isPurchasing) return;

    unawaited(ref.read(analyticsServiceProvider).trackRestoreInitiated());
    state = state.copyWith(isPurchasing: true, clearError: true);

    await _purchaseService.restorePurchases();

    // Wait a moment for any restored purchases to process
    await Future.delayed(const Duration(seconds: 2));

    state = state.copyWith(isPurchasing: false);

    // Refresh subscription status
    ref.read(subscriptionProvider.notifier).refresh();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}
