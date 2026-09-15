import 'dart:async';

import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/storage_service.dart';
import '../constants/billing_config.dart';
import '../repositories/subscription_repository.dart';
import 'purchase_mapping.dart';

/// Result of starting a purchase operation.
///
/// Success here only means the store sheet opened - the actual outcome arrives
/// later on the plugin's listeners, never as a return value.
class PurchaseResult {
  final bool success;
  final String? errorMessage;
  final String? productId;

  /// True when the purchase went through at the store but our backend could not
  /// confirm it yet. Premium is not active server-side, so the user must not be
  /// told they are a Premium member - only that it is being processed.
  final bool pendingVerification;

  const PurchaseResult({
    required this.success,
    this.errorMessage,
    this.productId,
    this.pendingVerification = false,
  });

  factory PurchaseResult.success(
    String productId, {
    bool pendingVerification = false,
  }) =>
      PurchaseResult(
        success: true,
        productId: productId,
        pendingVerification: pendingVerification,
      );

  factory PurchaseResult.failure(String error) => PurchaseResult(
        success: false,
        errorMessage: error,
      );
}

/// Service for handling in-app purchases via OpenIAP (`flutter_inapp_purchase`).
///
/// The OpenIAP contract this implements:
///   1. attach purchaseUpdatedListener + purchaseErrorListener
///   2. initConnection()
///   3. fetchProducts for in-app and for subs (two calls)
///   4. requestPurchase - outcome arrives on the listeners
///   5. on Purchased: verify with the backend, deliver, finishTransaction
///      on Pending: deliver nothing, finish nothing, say "payment pending"
///   6. reconcile getAvailablePurchases() after sign-in and on every resume
///   7. endConnection() on teardown
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final FlutterInappPurchase _iap = FlutterInappPurchase.instance;
  final SubscriptionRepository _subscriptionRepository =
      SubscriptionRepository();
  final StorageService _storage = StorageService();

  StreamSubscription<Purchase>? _purchaseSubscription;
  StreamSubscription<PurchaseError>? _errorSubscription;

  List<ProductCommon> _products = [];
  bool _isAvailable = false;
  bool _isInitialized = false;

  /// Purchase identities already delivered, so a replayed `getAvailablePurchases`
  /// does not grant (or re-verify) the same receipt twice.
  Set<String> _delivered = <String>{};

  /// Purchase identities currently being verified. The billing sheet closing IS
  /// an app resume, so the stream event and the resume reconcile can both see the
  /// same fresh purchase within a second; without this they double-verify.
  final Set<String> _fulfilling = <String>{};

  /// The signed-in user id, used as Play's `obfuscatedAccountId` and - when it is
  /// a UUID - Apple's `appAccountToken`.
  String? _userId;

  // Callbacks
  Function(PurchaseResult)? onPurchaseComplete;
  Function(String)? onPurchaseError;
  Function()? onPurchasePending;
  Function(PurchaseResult)? onPurchaseRestored;

  /// Whether the store connection is up.
  bool get isAvailable => _isAvailable;

  bool get isInitialized => _isInitialized;

  /// Products loaded from the store (subscriptions and the lifetime unlock).
  List<ProductCommon> get products => _products;

  ProductCommon? get monthlyProduct => _productById(ProductIds.monthlySubscription);

  ProductCommon? get yearlyProduct => _productById(ProductIds.yearlySubscription);

  ProductCommon? get lifetimeProduct => _productById(ProductIds.lifetimePurchase);

  ProductCommon? _productById(String id) =>
      _products.where((p) => p.id == id).firstOrNull;

  /// Initialize the store connection, listeners and product catalogue.
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing PurchaseService (OpenIAP)...');

    _delivered = await _storage.getDeliveredPurchaseIds();
    _userId = await _storage.getUserId();

    // Both listeners must be attached BEFORE initConnection, or an event that
    // arrives during connection setup (an unfinished purchase from last run) is
    // dropped.
    _purchaseSubscription = _iap.purchaseUpdatedListener.listen(
      (purchase) => unawaited(_onPurchaseUpdated(purchase)),
      onError: (Object error) =>
          AppLogger.error('Purchase stream error: $error'),
    );
    _errorSubscription = _iap.purchaseErrorListener.listen(
      _onPurchaseError,
      onError: (Object error) =>
          AppLogger.error('Purchase error stream failed: $error'),
    );

    try {
      _isAvailable = await _iap
          .initConnection()
          .timeout(const Duration(seconds: 10));
    } on PurchaseError catch (e) {
      AppLogger.warning('Store connection failed: ${e.message}');
      _isAvailable = false;
    } catch (e) {
      AppLogger.warning('Store connection failed: $e');
      _isAvailable = false;
    }

    if (!_isAvailable) {
      AppLogger.warning('In-app purchases not available on this device');
      _isInitialized = true;
      return;
    }

    await _loadProducts();

    _isInitialized = true;
    AppLogger.info(
        'PurchaseService initialized. Available: $_isAvailable, products: ${_products.length}');

    // Anything bought while the app was closed, or left unfinished last run.
    unawaited(reconcileStoreState());
  }

  /// Load the product catalogue with retry.
  ///
  /// Subscriptions and one-time products are separate queries under OpenIAP -
  /// asking for a subscription id with `ProductQueryType.InApp` simply returns
  /// nothing.
  Future<void> _loadProducts() async {
    final ids = BillingConfig.getProductIds();
    final subscriptionIds =
        ids.where(BillingConfig.isSubscription).toList(growable: false);
    final oneTimeIds =
        ids.where((id) => !BillingConfig.isSubscription(id)).toList(growable: false);

    for (var attempt = 1; attempt <= BillingConfig.maxRetryAttempts; attempt++) {
      try {
        final loaded = <ProductCommon>[];

        if (oneTimeIds.isNotEmpty) {
          loaded.addAll(await _iap.fetchProducts<Product>(
            skus: oneTimeIds,
            type: ProductQueryType.InApp,
          ));
        }

        if (subscriptionIds.isNotEmpty) {
          loaded.addAll(await _iap.fetchProducts<ProductSubscription>(
            skus: subscriptionIds,
            type: ProductQueryType.Subs,
          ));
        }

        _products = loaded;

        final notFound = ids.where((id) => !loaded.any((p) => p.id == id));
        if (notFound.isNotEmpty) {
          AppLogger.warning('Products not found: ${notFound.join(', ')}');
        }

        AppLogger.info('Loaded ${_products.length} products');
        for (final product in _products) {
          AppLogger.debug('Product: ${product.id} - ${displayPriceFor(product)}');
        }
        return;
      } catch (e) {
        AppLogger.error('Failed to load products (attempt $attempt): $e');
        if (attempt < BillingConfig.maxRetryAttempts) {
          await Future.delayed(BillingConfig.retryDelay);
        }
      }
    }
  }

  /// Handle one purchase from the store.
  Future<void> _onPurchaseUpdated(Purchase purchase) async {
    AppLogger.info(
        'Purchase update: ${purchase.productId} - ${purchase.purchaseState.value}');

    switch (purchase.purchaseState) {
      case PurchaseState.Pending:
        // A deferred payment (slow test card, cash, parental approval). Grant
        // nothing and finish nothing - it arrives again once it clears, which the
        // next app-resume reconcile picks up.
        onPurchasePending?.call();
        break;

      case PurchaseState.Purchased:
        await _fulfil(purchase);
        break;

      case PurchaseState.Unknown:
        AppLogger.warning(
            'Purchase in unknown state: ${purchase.productId}');
        onPurchaseError?.call('Purchase failed');
        break;
    }
  }

  /// Errors (including a user backing out of the sheet) arrive here, not on the
  /// purchase stream.
  void _onPurchaseError(PurchaseError error) {
    AppLogger.warning(
        'Purchase error: ${error.code?.value ?? 'unknown'} - ${error.message}');
    onPurchaseError?.call(purchaseErrorMessage(error));
  }

  /// Verify, deliver and finish a purchased receipt.
  Future<void> _fulfil(Purchase purchase, {bool isRestore = false}) async {
    final identity = purchaseIdentity(purchase);

    // Serialise per purchase: the stream event and the resume reconcile can both
    // reach the same receipt.
    if (identity != null && !_fulfilling.add(identity)) return;

    try {
      if (identity != null && _delivered.contains(identity)) {
        AppLogger.debug('Purchase already delivered: $identity');
        await _finish(purchase);
        return;
      }

      final payload = backendPayloadFor(purchase);
      if (payload == null) {
        // No token at all - there is nothing the backend could check.
        AppLogger.error('Purchase carries no token: ${purchase.productId}');
        onPurchaseError?.call('Purchase verification failed');
        return;
      }

      final response =
          await _verifyWithBackend(payload).timeout(
        BillingConfig.verificationTimeout,
        onTimeout: () => null,
      );
      final outcome = classifyVerifyResponse(response);
      final pendingVerification = outcome == VerifyOutcome.transient;

      switch (outcome) {
        case VerifyOutcome.granted:
          AppLogger.info('Purchase verified: ${purchase.productId}');
          break;

        case VerifyOutcome.transient:
          // The backend could not answer. Unlock anyway and replay the receipt
          // later - Play refunds anything unacknowledged within 3 days, so we
          // must not sit on a real purchase waiting for our own server.
          AppLogger.warning(
              'Purchase verification unavailable, queued for retry: ${purchase.productId}');
          await _queueForRetry(payload);
          break;

        case VerifyOutcome.rejected:
          AppLogger.warning('Purchase rejected by backend: ${purchase.productId}');
          onPurchaseError?.call('Purchase verification failed');
          // Android: leave it unacknowledged so Play refunds it. iOS: finish, or
          // StoreKit replays it on every launch forever.
          if (purchase is PurchaseIOS) {
            await _finish(purchase);
          }
          return;
      }

      if (identity != null) {
        _delivered = {..._delivered, identity};
        await _storage.addDeliveredPurchaseId(identity);
      }

      await _finish(purchase);

      final result = PurchaseResult.success(
        purchase.productId,
        pendingVerification: pendingVerification,
      );
      if (isRestore) {
        onPurchaseRestored?.call(result);
      } else {
        onPurchaseComplete?.call(result);
      }
    } catch (e) {
      AppLogger.error('Failed to fulfil purchase ${purchase.productId}: $e');
      onPurchaseError?.call('Purchase verification failed');
    } finally {
      if (identity != null) _fulfilling.remove(identity);
    }
  }

  Future<Map<String, dynamic>?> _verifyWithBackend(
    Map<String, dynamic> payload,
  ) {
    AppLogger.info('Verifying purchase: ${payload['product_id']}');
    return _subscriptionRepository.verifyPurchasePayload(payload);
  }

  /// Consume or acknowledge a purchase so Play does not refund it and StoreKit
  /// stops replaying it.
  Future<void> _finish(Purchase purchase) async {
    final consumable = isConsumableProduct(purchase.productId);

    if (!consumable &&
        purchase is PurchaseAndroid &&
        purchase.isAcknowledgedAndroid == true) {
      return;
    }

    try {
      await _iap.finishTransaction(
        purchase: purchase,
        isConsumable: consumable,
      );
    } catch (e) {
      AppLogger.error('Failed to finish transaction ${purchase.productId}: $e');
    }
  }

  Future<void> _queueForRetry(Map<String, dynamic> payload) async {
    final pending = await _storage.getPendingVerifications();
    final transactionId = payload['transaction_id'];
    final alreadyQueued = pending.any((entry) =>
        entry['transaction_id'] == transactionId &&
        entry['receipt_data'] == payload['receipt_data']);
    if (alreadyQueued) return;

    await _storage.savePendingVerifications([...pending, payload]);
  }

  /// Replay receipts the backend could not answer for. Anything it now accepts,
  /// or explicitly rejects, leaves the queue; only still-unreachable entries stay.
  Future<void> retryPendingVerifications() async {
    final pending = await _storage.getPendingVerifications();
    if (pending.isEmpty) return;

    AppLogger.info('Retrying ${pending.length} pending purchase verification(s)');

    final remaining = <Map<String, dynamic>>[];
    for (final payload in pending) {
      final response = await _verifyWithBackend(payload);
      if (classifyVerifyResponse(response) == VerifyOutcome.transient) {
        remaining.add(payload);
      }
    }

    await _storage.savePendingVerifications(remaining);
  }

  /// Re-read the store and run every owned purchase through the fulfilment path.
  ///
  /// Call this once after sign-in and on every app resume. `getAvailablePurchases`
  /// returns current entitlements plus anything unfinished, and the delivered set
  /// keeps repeats from re-granting.
  Future<void> reconcileStoreState({bool isRestore = false}) async {
    if (!_isAvailable) return;

    try {
      final purchases = await _iap.getAvailablePurchases();
      AppLogger.debug('Reconciling ${purchases.length} store purchase(s)');

      for (final purchase in purchases) {
        if (purchase.purchaseState == PurchaseState.Purchased) {
          await _fulfil(purchase, isRestore: isRestore);
        }
      }
    } catch (e) {
      AppLogger.error('Failed to reconcile store state: $e');
    }

    unawaited(retryPendingVerifications());
  }

  /// Purchase a product. The outcome arrives on the listeners, not here.
  Future<PurchaseResult> purchase(ProductCommon product) async {
    if (!_isAvailable) {
      return PurchaseResult.failure('Store not available');
    }

    return _requestPurchase(product);
  }

  /// Change an existing subscription (upgrade/downgrade).
  ///
  /// iOS handles a plan change inside the same product group automatically, so
  /// there it is an ordinary purchase. On Android the old subscription's token
  /// and product id must be passed so Play replaces it with time proration
  /// instead of starting a second one.
  Future<PurchaseResult> changeSubscription(ProductCommon newProduct) async {
    if (!_isAvailable) {
      return PurchaseResult.failure('Store not available');
    }

    final active = await _activeSubscription();
    if (active == null || active.productId == newProduct.id) {
      return _requestPurchase(newProduct);
    }

    AppLogger.info(
        'Changing subscription ${active.productId} -> ${newProduct.id}');

    return _requestPurchase(
      newProduct,
      oldPurchaseToken: active.purchaseTokenAndroid ?? active.purchaseToken,
      oldProductId: active.productId,
    );
  }

  Future<PurchaseResult> _requestPurchase(
    ProductCommon product, {
    String? oldPurchaseToken,
    String? oldProductId,
  }) async {
    try {
      AppLogger.info('Starting purchase: ${product.id}');

      String? offerToken;
      if (product is ProductSubscriptionAndroid) {
        // Android rejects a subscription request with no offer token as a
        // developer error on the native side.
        offerToken = selectAndroidOffer(product.subscriptionOffers)
            ?.offerTokenAndroid;
        if (offerToken == null) {
          AppLogger.error('No purchasable offer for ${product.id}');
          return PurchaseResult.failure(
              'This plan is not available on your account right now');
        }
      }

      await _iap.requestPurchase(buildPurchaseProps(
        productId: product.id,
        userId: _userId,
        androidOfferToken: offerToken,
        oldPurchaseToken: oldPurchaseToken,
        oldProductId: oldProductId,
      ));

      // The sheet is open; the result comes back on the listeners.
      return PurchaseResult(success: true, productId: product.id);
    } on PurchaseError catch (e) {
      AppLogger.error('Purchase failed: ${e.message}');
      return PurchaseResult.failure(purchaseErrorMessage(e));
    } catch (e) {
      AppLogger.error('Purchase failed: $e');
      return PurchaseResult.failure(e.toString());
    }
  }

  Future<ActiveSubscription?> _activeSubscription() async {
    try {
      final active = await _iap
          .getActiveSubscriptions(ProductIds.subscriptions.toList());
      return active.where((s) => s.isActive).firstOrNull ?? active.firstOrNull;
    } catch (e) {
      AppLogger.error('Failed to read active subscriptions: $e');
      return null;
    }
  }

  /// Restore previous purchases.
  ///
  /// Under OpenIAP nothing is re-emitted on the purchase stream by a restore;
  /// the owned items come back from `getAvailablePurchases`, which
  /// [reconcileStoreState] walks.
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store not available');
      return;
    }

    try {
      AppLogger.info('Restoring purchases...');
      // Restore is the user's escape hatch, so it must not be short-circuited by
      // the dedup set: forget what we think was delivered and re-verify every
      // owned purchase from scratch.
      _delivered = <String>{};
      await _storage.clearDeliveredPurchaseIds();

      await _iap.restorePurchases();
      await reconcileStoreState(isRestore: true);
    } on PurchaseError catch (e) {
      AppLogger.error('Failed to restore purchases: ${e.message}');
      onPurchaseError?.call(purchaseErrorMessage(e));
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      onPurchaseError?.call('Failed to restore purchases');
    }
  }

  /// Tell the service which user is signed in, and reconcile anything they own.
  ///
  /// The id tags purchases at the store (Play `obfuscatedAccountId`, Apple
  /// `appAccountToken`), which is what lets a deferred-payment webhook find the
  /// account later.
  Future<void> setUser(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    if (userId != null) {
      await reconcileStoreState();
    }
  }

  /// Get the display price for a product, or null when it did not load.
  String? getFormattedPrice(String productId) {
    final product = _productById(productId);
    return product == null ? null : displayPriceFor(product);
  }

  /// Dispose the service and close the store connection.
  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _errorSubscription?.cancel();
    _purchaseSubscription = null;
    _errorSubscription = null;

    if (_isAvailable) {
      try {
        await _iap.endConnection();
      } catch (e) {
        AppLogger.error('Failed to end store connection: $e');
      }
    }

    _isInitialized = false;
    _isAvailable = false;
  }
}
