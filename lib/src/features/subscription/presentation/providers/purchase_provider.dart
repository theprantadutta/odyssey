import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/services/purchase_service.dart';
import 'subscription_provider.dart';

part 'purchase_provider.g.dart';

/// State for purchase operations
class PurchaseState {
  final bool isInitialized;
  final bool isAvailable;
  final bool isPurchasing;
  final List<ProductDetails> products;
  final String? error;
  final String? successMessage;

  const PurchaseState({
    this.isInitialized = false,
    this.isAvailable = false,
    this.isPurchasing = false,
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
    List<ProductDetails>? products,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PurchaseState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAvailable: isAvailable ?? this.isAvailable,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Purchase state notifier provider
@riverpod
class Purchase extends _$Purchase {
  late final PurchaseService _purchaseService;

  @override
  PurchaseState build() {
    _purchaseService = PurchaseService();

    // Set up callbacks
    _purchaseService.onPurchaseComplete = _onPurchaseComplete;
    _purchaseService.onPurchaseError = _onPurchaseError;
    _purchaseService.onPurchasePending = _onPurchasePending;

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

  void _onPurchaseComplete(PurchaseResult result) {
    AppLogger.info('Purchase complete: ${result.productId}');
    state = state.copyWith(
      isPurchasing: false,
      successMessage: 'Purchase successful! You are now a Premium member.',
      clearError: true,
    );

    // Refresh subscription status
    ref.read(subscriptionProvider.notifier).refresh();
  }

  void _onPurchaseError(String error) {
    AppLogger.error('Purchase error: $error');
    state = state.copyWith(
      isPurchasing: false,
      error: error,
      clearSuccess: true,
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
    await _purchase(product);
  }

  /// Purchase yearly subscription
  Future<void> purchaseYearly() async {
    final product = state.yearlyProduct;
    if (product == null) {
      state = state.copyWith(error: 'Yearly subscription not available');
      return;
    }
    await _purchase(product);
  }

  /// Purchase lifetime
  Future<void> purchaseLifetime() async {
    final product = state.lifetimeProduct;
    if (product == null) {
      state = state.copyWith(error: 'Lifetime purchase not available');
      return;
    }
    await _purchase(product);
  }

  Future<void> _purchase(ProductDetails product) async {
    if (state.isPurchasing) return;

    state = state.copyWith(isPurchasing: true, clearError: true);

    final result = await _purchaseService.purchase(product);

    if (!result.success) {
      state = state.copyWith(
        isPurchasing: false,
        error: result.errorMessage ?? 'Purchase failed',
      );
    }
    // Success will be handled by the stream callback
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (state.isPurchasing) return;

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
