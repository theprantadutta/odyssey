import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';

import '../constants/billing_config.dart';

/// Pure, dependency-free helpers for the OpenIAP purchase flow.
///
/// Everything in this file is a plain function over plugin value types, so it can
/// be unit tested without a store connection. [PurchaseService] stays a thin shell
/// that talks to the plugin and delegates every decision here.

/// What the backend said about a receipt, and therefore what the client must do.
enum VerifyOutcome {
  /// Backend verified the receipt. Deliver, mark delivered, finish.
  granted,

  /// Backend could not answer (offline, 5xx, 401, pending at the store).
  /// Deliver locally, queue the receipt for retry, and still finish the
  /// transaction - Play refunds anything unacknowledged for 3 days.
  transient,

  /// Backend explicitly rejected the receipt. Deliver nothing. On Android do
  /// NOT finish (let Play refund it); on iOS finish so it stops replaying.
  rejected,
}

/// Backend error prefixes that mean "ask again later", not "this is fake".
const Set<String> transientVerifyErrorPrefixes = {
  'PURCHASE_VERIFICATION_UNAVAILABLE',
  'PURCHASE_PENDING',
};

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Stable identity used to dedup delivery and to serialise in-flight fulfilment.
///
/// Android: the Play order id when present, falling back to the purchase token
/// (`PurchaseAndroid.id` is exactly that fallback, and the order id is null while
/// a purchase is pending). iOS: the StoreKit 2 transaction id.
///
/// Using the order id on Android keeps the persisted "already delivered" set
/// meaningful across the upgrade from `in_app_purchase`, whose `purchaseID` was
/// the same value.
String? purchaseIdentity(Purchase purchase) {
  final id = switch (purchase) {
    PurchaseAndroid(:final transactionId, :final id, :final purchaseToken) =>
      transactionId ?? (id.isNotEmpty ? id : purchaseToken),
    PurchaseIOS(:final transactionId) => transactionId,
  };
  if (id == null || id.isEmpty) return null;
  return id;
}

/// The request body for `POST /subscription/purchase/verify`.
///
/// Returns null when the purchase carries no token at all - there is nothing the
/// backend could verify, so it must be treated as [VerifyOutcome.rejected].
///
/// `receipt_data` is the purchase token on Android and the StoreKit 2 JWS on iOS;
/// the plugin unifies both under [Purchase.purchaseToken]. The keys match what the
/// pre-migration client sent, so queued receipts persisted by the old plugin still
/// parse after the upgrade.
Map<String, dynamic>? backendPayloadFor(Purchase purchase) {
  final token = purchase.purchaseToken;
  if (token == null || token.isEmpty) return null;

  return {
    'product_id': purchase.productId,
    'transaction_id': purchaseIdentity(purchase),
    'platform': purchase is PurchaseAndroid ? 'android' : 'ios',
    'receipt_data': token,
    'purchase_token': token,
  };
}

/// Classifies a `/purchase/verify` response body into an outcome.
///
/// [body] is null when the call threw (offline, timeout, 401, 5xx) - always
/// transient, never a rejection, because an unreachable backend must not cost the
/// user a purchase they actually paid for.
VerifyOutcome classifyVerifyResponse(Map<String, dynamic>? body) {
  if (body == null) return VerifyOutcome.transient;

  final verified = body['verified'] as bool? ?? false;
  if (verified) return VerifyOutcome.granted;

  final error = body['error'] as String?;
  if (error != null && isTransientVerifyError(error)) {
    return VerifyOutcome.transient;
  }

  return VerifyOutcome.rejected;
}

/// Whether a backend error string is one of the retryable, prefix-matched codes.
bool isTransientVerifyError(String error) {
  return transientVerifyErrorPrefixes.any(error.startsWith);
}

/// Whether the purchase must be consumed rather than acknowledged.
///
/// Every Odyssey product is a subscription or the one-time lifetime unlock, and
/// none of them may be bought twice - so nothing is consumable.
bool isConsumableProduct(String productId) => false;

/// Picks the Android subscription offer to buy.
///
/// `requestPurchase` for a `subs` product without an offer token is a developer
/// error on the native side, so this must always resolve to something when the
/// product has offers. Preference order:
///   1. a free-trial offer (a zero-priced, non-infinite pricing phase),
///   2. the base plan (`offer.id == offer.basePlanIdAndroid`),
///   3. the first offer.
///
/// Play only returns offers the user is actually eligible for, so preferring the
/// trial is safe.
SubscriptionOffer? selectAndroidOffer(List<SubscriptionOffer> offers) {
  if (offers.isEmpty) return null;

  for (final offer in offers) {
    if (offer.offerTokenAndroid == null) continue;
    if (offerHasFreeTrial(offer)) return offer;
  }

  for (final offer in offers) {
    if (offer.offerTokenAndroid == null) continue;
    if (offer.basePlanIdAndroid != null && offer.id == offer.basePlanIdAndroid) {
      return offer;
    }
  }

  for (final offer in offers) {
    if (offer.offerTokenAndroid != null) return offer;
  }

  return null;
}

/// True when an Android offer starts with a free phase that eventually ends.
///
/// `recurrenceMode`: 1 = infinite recurring, 2 = finite recurring, 3 = non-recurring.
/// A zero-priced *infinite* phase would be a free plan, not a trial.
bool offerHasFreeTrial(SubscriptionOffer offer) {
  final phases = offer.pricingPhasesAndroid?.pricingPhaseList;
  if (phases == null || phases.isEmpty) return false;

  final first = phases.first;
  return first.priceAmountMicros == '0' && first.recurrenceMode != 1;
}

/// The price to show on a plan card.
///
/// A subscription's [ProductCommon.displayPrice] reads "Free" whenever a trial
/// phase comes first, which would advertise the wrong price. For Android
/// subscriptions the recurring price is the last non-zero pricing phase of the
/// chosen offer; everything else can use `displayPrice` directly.
String displayPriceFor(ProductCommon product) {
  if (product is! ProductSubscriptionAndroid) return product.displayPrice;

  final offer = selectAndroidOffer(product.subscriptionOffers);
  final phases = offer?.pricingPhasesAndroid?.pricingPhaseList;
  if (phases == null || phases.isEmpty) return product.displayPrice;

  for (final phase in phases.reversed) {
    if (phase.priceAmountMicros != '0') return phase.formattedPrice;
  }

  return product.displayPrice;
}

/// The `appAccountToken` to send to Apple, or null when the id is unusable.
///
/// The OpenIAP Apple module throws on a non-UUID value (Apple itself would
/// silently drop it), so anything that is not a plain UUID must be omitted.
String? appleAccountTokenFor(String? userId) {
  if (userId == null || userId.isEmpty) return null;
  return _uuidPattern.hasMatch(userId) ? userId : null;
}

/// The `obfuscatedAccountId` to send to Play. Any non-empty string is accepted.
String? androidAccountIdFor(String? userId) {
  if (userId == null || userId.isEmpty) return null;
  return userId;
}

/// Builds the `requestPurchase` props for a product, choosing the in-app or
/// subscription shape from [BillingConfig.isSubscription].
///
/// [oldPurchaseToken] and [oldProductId] switch an existing Android subscription
/// to [productId] with time proration instead of starting a second one.
RequestPurchaseProps buildPurchaseProps({
  required String productId,
  String? userId,
  String? androidOfferToken,
  String? oldPurchaseToken,
  String? oldProductId,
}) {
  final appleToken = appleAccountTokenFor(userId);
  final androidAccountId = androidAccountIdFor(userId);

  if (!BillingConfig.isSubscription(productId)) {
    return RequestPurchaseProps.inApp((
      apple: RequestPurchaseIosProps(
        sku: productId,
        appAccountToken: appleToken,
      ),
      google: RequestPurchaseAndroidProps(
        skus: [productId],
        obfuscatedAccountId: androidAccountId,
      ),
    ));
  }

  final isReplacement = oldPurchaseToken != null &&
      oldPurchaseToken.isNotEmpty &&
      oldProductId != null &&
      oldProductId.isNotEmpty &&
      oldProductId != productId;

  return RequestPurchaseProps.subs((
    apple: RequestSubscriptionIosProps(
      sku: productId,
      appAccountToken: appleToken,
    ),
    google: RequestSubscriptionAndroidProps(
      skus: [productId],
      obfuscatedAccountId: androidAccountId,
      subscriptionOffers: androidOfferToken == null
          ? null
          : [
              AndroidSubscriptionOfferInput(
                sku: productId,
                offerToken: androidOfferToken,
              ),
            ],
      purchaseToken: isReplacement ? oldPurchaseToken : null,
      subscriptionProductReplacementParams: isReplacement
          ? SubscriptionProductReplacementParamsAndroid(
              oldProductId: oldProductId,
              replacementMode:
                  SubscriptionReplacementModeAndroid.WithTimeProration,
            )
          : null,
    ),
  ));
}

/// Maps a plugin error onto the message shown to the user.
String purchaseErrorMessage(PurchaseError error) {
  return switch (error.code) {
    ErrorCode.UserCancelled => 'Purchase was canceled',
    ErrorCode.AlreadyOwned =>
      'You already own this plan. Try Restore Purchases.',
    ErrorCode.ItemUnavailable || ErrorCode.SkuNotFound =>
      'This plan is not available right now',
    ErrorCode.NetworkError || ErrorCode.ServiceError || ErrorCode.ServiceTimeout =>
      'Could not reach the store. Check your connection and try again.',
    ErrorCode.BillingUnavailable || ErrorCode.IapNotAvailable =>
      'In-app purchases are not available on this device',
    ErrorCode.DeferredPayment || ErrorCode.Pending =>
      'Your payment is pending approval',
    _ => error.message.isEmpty ? 'Purchase failed' : error.message,
  };
}

/// Whether an error means the user backed out, rather than something failing.
bool isUserCancellation(PurchaseError error) =>
    error.code == ErrorCode.UserCancelled;
