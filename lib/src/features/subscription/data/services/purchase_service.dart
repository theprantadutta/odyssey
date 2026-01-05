import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/services/logger_service.dart';
import '../repositories/subscription_repository.dart';

/// Product IDs for different subscription tiers
/// These must match the IDs configured in App Store Connect and Google Play Console
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
}

/// Result of a purchase operation
class PurchaseResult {
  final bool success;
  final String? errorMessage;
  final String? productId;

  const PurchaseResult({
    required this.success,
    this.errorMessage,
    this.productId,
  });

  factory PurchaseResult.success(String productId) => PurchaseResult(
        success: true,
        productId: productId,
      );

  factory PurchaseResult.failure(String error) => PurchaseResult(
        success: false,
        errorMessage: error,
      );
}

/// Service for handling in-app purchases
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SubscriptionRepository _subscriptionRepository = SubscriptionRepository();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isInitialized = false;

  // Callbacks
  Function(PurchaseResult)? onPurchaseComplete;
  Function(String)? onPurchaseError;
  Function()? onPurchasePending;

  /// Check if store is available
  bool get isAvailable => _isAvailable;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get available products
  List<ProductDetails> get products => _products;

  /// Get monthly product
  ProductDetails? get monthlyProduct => _products
      .where((p) => p.id == ProductIds.monthlySubscription)
      .firstOrNull;

  /// Get yearly product
  ProductDetails? get yearlyProduct =>
      _products.where((p) => p.id == ProductIds.yearlySubscription).firstOrNull;

  /// Get lifetime product
  ProductDetails? get lifetimeProduct =>
      _products.where((p) => p.id == ProductIds.lifetimePurchase).firstOrNull;

  /// Initialize the purchase service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing PurchaseService...');

    _isAvailable = await _inAppPurchase.isAvailable();

    if (!_isAvailable) {
      AppLogger.warning('In-app purchases not available on this device');
      _isInitialized = true;
      return;
    }

    // Platform-specific configuration is handled by the in_app_purchase package

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        AppLogger.error('Purchase stream error: $error');
      },
    );

    // Load products
    await _loadProducts();

    _isInitialized = true;
    AppLogger.info('PurchaseService initialized. Available: $_isAvailable');
  }

  /// Load available products from the store
  Future<void> _loadProducts() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(ProductIds.all);

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.warning('Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        AppLogger.error('Error loading products: ${response.error}');
        return;
      }

      _products = response.productDetails;
      AppLogger.info('Loaded ${_products.length} products');

      for (final product in _products) {
        AppLogger.debug('Product: ${product.id} - ${product.price}');
      }
    } catch (e) {
      AppLogger.error('Failed to load products: $e');
    }
  }

  /// Handle purchase updates from the store
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      AppLogger.info('Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await _verifyPurchase(purchase);
          if (verified) {
            await _deliverProduct(purchase);
            onPurchaseComplete?.call(PurchaseResult.success(purchase.productID));
          } else {
            onPurchaseError?.call('Purchase verification failed');
          }
          break;

        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
          break;

        case PurchaseStatus.canceled:
          onPurchaseError?.call('Purchase was canceled');
          break;
      }

      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Verify purchase with backend
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      AppLogger.info('Verifying purchase: ${purchase.productID}');

      // Get verification data from the purchase
      final receiptData = purchase.verificationData.serverVerificationData;
      final localData = purchase.verificationData.localVerificationData;
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Verify with backend
      final result = await _subscriptionRepository.verifyPurchase(
        productId: purchase.productID,
        receiptData: receiptData,
        signature: localData, // On Android, this contains the signature
        platform: platform,
      );

      return result;
    } catch (e) {
      AppLogger.error('Purchase verification failed: $e');
      return false;
    }
  }

  /// Deliver product after successful purchase
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    AppLogger.info('Delivering product: ${purchase.productID}');
    // The backend already updated the subscription during verification
    // We just log this for tracking
  }

  /// Purchase a product
  Future<PurchaseResult> purchase(ProductDetails product) async {
    if (!_isAvailable) {
      return PurchaseResult.failure('Store not available');
    }

    try {
      AppLogger.info('Starting purchase: ${product.id}');

      final purchaseParam = PurchaseParam(productDetails: product);

      // All our products are non-consumable (subscriptions and lifetime)
      final success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        return PurchaseResult.failure('Failed to initiate purchase');
      }

      // Purchase flow started - result will come via stream
      return PurchaseResult(success: true, productId: product.id);
    } catch (e) {
      AppLogger.error('Purchase failed: $e');
      return PurchaseResult.failure(e.toString());
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store not available');
      return;
    }

    try {
      AppLogger.info('Restoring purchases...');
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      onPurchaseError?.call('Failed to restore purchases: $e');
    }
  }

  /// Get formatted price for a product
  String? getFormattedPrice(String productId) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    return product?.price;
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _isInitialized = false;
  }
}
