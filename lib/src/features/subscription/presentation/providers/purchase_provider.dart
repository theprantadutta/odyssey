import 'dart:async';

import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/constants/billing_config.dart';
import '../../data/services/purchase_mapping.dart';
import '../../data/services/purchase_service.dart';
import 'subscription_provider.dart';

part 'purchase_provider.g.dart';

/// State for purchase operations
class PurchaseState {
  final bool isInitialized;
  final bool isAvailable;
  final bool isPurchasing;
  final String? activeProductId;
  final List<ProductCommon> products;
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

  ProductCommon? get monthlyProduct =>
      products.where((p) => p.id == ProductIds.monthlySubscription).firstOrNull;

  ProductCommon? get yearlyProduct =>
      products.where((p) => p.id == ProductIds.yearlySubscription).firstOrNull;

  ProductCommon? get lifetimeProduct =>
      products.where((p) => p.id == ProductIds.lifetimePurchase).firstOrNull;

  /// Prices as the store would charge them.
  ///
  /// Not `displayPrice`: an Android subscription whose first pricing phase is a
  /// free trial reports "Free" there, which would advertise the wrong number.
  String? get monthlyPrice => _priceOf(monthlyProduct);
  String? get yearlyPrice => _priceOf(yearlyProduct);
  String? get lifetimePrice => _priceOf(lifetimeProduct);

  static String? _priceOf(ProductCommon? product) =>
      product == null ? null : displayPriceFor(product);

  PurchaseState copyWith({
    bool? isInitialized,
    bool? isAvailable,
    bool? isPurchasing,
    String? activeProductId,
    List<ProductCommon>? products,
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
  /// How long a purchase may sit "in progress" with no outcome before a resume
  /// is allowed to clear it. Android sometimes closes the billing sheet without
  /// emitting anything at all, which would otherwise leave the paywall spinning
  /// with no way out.
  static const Duration _purchaseWatchdog = Duration(seconds: 20);

  late final PurchaseService _purchaseService;

  DateTime? _purchaseStartedAt;

  @override
  PurchaseState build() {
    _purchaseService = PurchaseService();

    // Set up callbacks
    _purchaseService.onPurchaseComplete = _onPurchaseComplete;
    _purchaseService.onPurchaseError = _onPurchaseError;
    _purchaseService.onPurchasePending = _onPurchasePending;
    _purchaseService.onPurchaseRestored = _onPurchaseRestored;

    // Tag purchases with the signed-in account and, once after sign-in, fulfil
    // anything the store already reports as owned for them.
    ref.listen(authProvider, (previous, next) {
      if (previous?.user?.id == next.user?.id) return;
      unawaited(_purchaseService.setUser(next.user?.id));
    });

    // Initialize on build
    _initialize();

    return const PurchaseState();
  }

  /// Re-run store initialisation. Exposed so the paywall can offer a Retry when
  /// StoreKit returned no products - a reviewer must never be left on a paywall that
  /// looks purchasable but cannot complete a purchase.
  Future<void> retry() async {
    state = state.copyWith(isInitialized: false, error: null);
    await _initialize();
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
    _purchaseStartedAt = null;
    unawaited(ref.read(analyticsServiceProvider).trackPurchaseCompleted(
          plan: _planFromProductId(result.productId),
        ));
    state = state.copyWith(
      isPurchasing: false,
      successMessage: result.pendingVerification
          ? 'Thanks! Your purchase went through and is being confirmed - '
              'Premium unlocks shortly.'
          : 'Purchase successful! You are now a Premium member.',
      clearError: true,
      clearActiveProduct: true,
    );

    // Force refresh from server to get updated Premium status immediately
    ref.read(subscriptionProvider.notifier).forceRefresh();
  }

  void _onPurchaseRestored(PurchaseResult result) {
    AppLogger.info('Purchase restored: ${result.productId}');
    _purchaseStartedAt = null;
    state = state.copyWith(
      isPurchasing: false,
      successMessage: 'Purchases restored successfully!',
      clearError: true,
      clearActiveProduct: true,
    );

    ref.read(subscriptionProvider.notifier).forceRefresh();
  }

  void _onPurchaseError(String error) {
    AppLogger.error('Purchase error: $error');
    _purchaseStartedAt = null;
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

  /// A deferred payment: the sheet is done but the money is not. Nothing is
  /// unlocked, so the spinner has to stop and say why.
  void _onPurchasePending() {
    AppLogger.info('Purchase pending');
    _purchaseStartedAt = null;
    state = state.copyWith(
      isPurchasing: false,
      error: 'Your payment is pending approval. Premium unlocks as soon as it '
          'clears - no need to buy again.',
      clearSuccess: true,
      clearActiveProduct: true,
    );
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

  Future<void> _purchase(ProductCommon product) async {
    if (state.isPurchasing) return;

    _purchaseStartedAt = DateTime.now();
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

  Future<void> _changeSubscription(ProductCommon product) async {
    if (state.isPurchasing) return;

    _purchaseStartedAt = DateTime.now();
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

  /// Restore previous purchases.
  ///
  /// OpenIAP re-emits nothing on the purchase stream for a restore, so this
  /// awaits the reconcile against `getAvailablePurchases` rather than sleeping
  /// and hoping events showed up.
  Future<void> restorePurchases() async {
    if (state.isPurchasing) return;

    unawaited(ref.read(analyticsServiceProvider).trackRestoreInitiated());
    state = state.copyWith(isPurchasing: true, clearError: true);

    await _purchaseService.restorePurchases();

    state = state.copyWith(isPurchasing: false);

    // Force refresh from server to get updated status immediately
    ref.read(subscriptionProvider.notifier).forceRefresh();
  }

  /// Re-read the store and fulfil anything owned but not yet delivered.
  ///
  /// Call on app resume: the billing sheet closing is itself a resume, and a
  /// deferred payment that cleared in the background only shows up here.
  Future<void> reconcileStoreState() async {
    await _purchaseService.reconcileStoreState();
    _clearStuckPurchase();
  }

  /// Release a purchase that never produced an outcome.
  ///
  /// Only after the reconcile has run, so a purchase that did succeed is already
  /// reflected before the spinner is taken away.
  void _clearStuckPurchase() {
    if (!state.isPurchasing) return;

    final startedAt = _purchaseStartedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt) < _purchaseWatchdog) {
      return;
    }

    AppLogger.warning('Clearing stuck purchase state');
    _purchaseStartedAt = null;
    state = state.copyWith(isPurchasing: false, clearActiveProduct: true);
  }

  /// Tell the store which user is signed in, so purchases carry an account tag.
  Future<void> setUser(String? userId) => _purchaseService.setUser(userId);


  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }
}
