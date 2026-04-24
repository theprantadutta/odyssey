import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import '../../../../core/services/logger_service.dart';
import '../constants/billing_config.dart';
import '../repositories/subscription_repository.dart';

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
  final SubscriptionRepository _subscriptionRepository =
      SubscriptionRepository();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  bool _isAvailable = false;
  bool _isInitialized = false;

  // Callbacks
  Function(PurchaseResult)? onPurchaseComplete;
  Function(String)? onPurchaseError;
  Function()? onPurchasePending;
  Function(PurchaseResult)? onPurchaseRestored;

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
  ProductDetails? get yearlyProduct => _products
      .where((p) => p.id == ProductIds.yearlySubscription)
      .firstOrNull;

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

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        AppLogger.error('Purchase stream error: $error');
      },
    );

    // Load products with retry
    await _loadProducts();

    _isInitialized = true;
    AppLogger.info('PurchaseService initialized. Available: $_isAvailable');
  }

  /// Load available products from the store with retry logic
  Future<void> _loadProducts() async {
    for (var attempt = 1; attempt <= BillingConfig.maxRetryAttempts; attempt++) {
      try {
        final productIds = BillingConfig.getProductIds();
        final response = await _inAppPurchase.queryProductDetails(productIds);

        if (response.notFoundIDs.isNotEmpty) {
          AppLogger.warning('Products not found: ${response.notFoundIDs}');
        }

        if (response.error != null) {
          AppLogger.error(
              'Error loading products (attempt $attempt): ${response.error}');
          if (attempt < BillingConfig.maxRetryAttempts) {
            await Future.delayed(BillingConfig.retryDelay);
            continue;
          }
          return;
        }

        _products = response.productDetails;
        AppLogger.info('Loaded ${_products.length} products');

        for (final product in _products) {
          AppLogger.debug('Product: ${product.id} - ${product.price}');
        }
        return; // Success, exit retry loop
      } catch (e) {
        AppLogger.error(
            'Failed to load products (attempt $attempt): $e');
        if (attempt < BillingConfig.maxRetryAttempts) {
          await Future.delayed(BillingConfig.retryDelay);
        }
      }
    }
  }

  /// Handle purchase updates from the store
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      AppLogger.info(
          'Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await _verifyPurchase(purchase);
          if (verified) {
            await _deliverProduct(purchase);
            if (purchase.status == PurchaseStatus.restored) {
              onPurchaseRestored
                  ?.call(PurchaseResult.success(purchase.productID));
            } else {
              onPurchaseComplete
                  ?.call(PurchaseResult.success(purchase.productID));
            }
          } else {
            onPurchaseError?.call('Purchase verification failed');
          }

          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          onPurchaseError?.call('Purchase was canceled');
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          break;
      }

      // Track purchases for subscription change support
      _purchases = [
        ..._purchases.where((p) => p.productID != purchase.productID),
        purchase
      ];
    }
  }

  /// Verify purchase with backend
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      AppLogger.info('Verifying purchase: ${purchase.productID}');

      // Extract the purchase token based on platform
      String purchaseToken;
      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.billingClientPurchase.purchaseToken;
      } else {
        purchaseToken = purchase.verificationData.serverVerificationData;
      }

      final localData = purchase.verificationData.localVerificationData;
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Verify with backend
      final result = await _subscriptionRepository.verifyPurchase(
        productId: purchase.productID,
        receiptData: purchaseToken,
        signature: localData,
        platform: platform,
      ).timeout(BillingConfig.verificationTimeout);

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
      final success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

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

  /// Change an existing subscription (upgrade/downgrade).
  /// On iOS, delegates to regular purchase (iOS handles it automatically).
  /// On Android, uses ChangeSubscriptionParam with proration.
  Future<PurchaseResult> changeSubscription(ProductDetails newProduct) async {
    if (!_isAvailable) {
      return PurchaseResult.failure('Store not available');
    }

    if (!Platform.isAndroid) {
      // iOS handles upgrades/downgrades automatically
      return purchase(newProduct);
    }

    final existingPurchase = getExistingSubscription();
    if (existingPurchase == null) {
      // No existing subscription, just purchase normally
      return purchase(newProduct);
    }

    try {
      AppLogger.info(
          'Changing subscription to: ${newProduct.id}');

      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: newProduct,
        changeSubscriptionParam: ChangeSubscriptionParam(
          oldPurchaseDetails: existingPurchase,
          replacementMode: ReplacementMode.withTimeProration,
        ),
      );

      final success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        return PurchaseResult.failure('Failed to initiate subscription change');
      }

      return PurchaseResult(success: true, productId: newProduct.id);
    } catch (e) {
      AppLogger.error('Subscription change failed: $e');
      return PurchaseResult.failure(e.toString());
    }
  }

  /// Get existing active subscription for Android upgrade/downgrade
  GooglePlayPurchaseDetails? getExistingSubscription() {
    try {
      for (final purchase in _purchases) {
        if (purchase.status == PurchaseStatus.purchased &&
            purchase is GooglePlayPurchaseDetails) {
          return purchase;
        }
      }
    } catch (_) {}
    return null;
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
