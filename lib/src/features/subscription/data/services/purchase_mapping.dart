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
    if (offer.basePlanIdAndroid != null &&
        offer.id == offer.basePlanIdAndroid) {
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

/// The unit of an ISO-8601 duration as the stores use them (`P7D`, `P1W`,
/// `P1M`, `P1Y`).
enum PeriodUnit { day, week, month, year }

/// A single-unit ISO-8601 duration, e.g. `P7D` -> (count: 7, unit: day).
typedef StorePeriod = ({int count, PeriodUnit unit});

final RegExp _isoPeriodPattern = RegExp(
  r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
);

/// Parses a store billing period such as `P7D`, `P1W`, `P3M` or `P1Y`.
///
/// Weeks and days together (`P1W3D`) fold into days. Any other mix of units, a
/// zero or empty duration, or a malformed string returns null - callers treat
/// that as "cannot describe this honestly" and show nothing trial-related.
StorePeriod? parseStorePeriod(String iso) {
  final match = _isoPeriodPattern.firstMatch(iso.trim().toUpperCase());
  if (match == null) return null;

  int? part(int group) {
    final raw = match.group(group);
    return raw == null ? null : int.tryParse(raw);
  }

  final years = part(1);
  final months = part(2);
  final weeks = part(3);
  final days = part(4);

  final dayLike = weeks != null || days != null;
  final unitsUsed = [
    years != null,
    months != null,
    dayLike,
  ].where((used) => used).length;
  if (unitsUsed != 1) return null;

  final StorePeriod period;
  if (years != null) {
    period = (count: years, unit: PeriodUnit.year);
  } else if (months != null) {
    period = (count: months, unit: PeriodUnit.month);
  } else if (days == null) {
    period = (count: weeks!, unit: PeriodUnit.week);
  } else {
    period = (count: (weeks ?? 0) * 7 + days, unit: PeriodUnit.day);
  }

  return period.count > 0 ? period : null;
}

/// [period] repeated [times] times, e.g. two cycles of `P1W` -> 2 weeks.
StorePeriod _times(StorePeriod period, int times) =>
    times <= 1 ? period : (count: period.count * times, unit: period.unit);

String _unitName(PeriodUnit unit) => switch (unit) {
  PeriodUnit.day => 'day',
  PeriodUnit.week => 'week',
  PeriodUnit.month => 'month',
  PeriodUnit.year => 'year',
};

/// Weeks read as days in a trial ("7 days free", not "1 week free") - that is
/// how Play and most paywalls phrase it, and it is unambiguous.
StorePeriod _trialUnits(StorePeriod period) => period.unit == PeriodUnit.week
    ? (count: period.count * 7, unit: PeriodUnit.day)
    : period;

/// "7 days", "1 month", "1 year" - the trial length as a noun phrase.
String trialDurationLabel(StorePeriod period) {
  final p = _trialUnits(period);
  final unit = _unitName(p.unit);
  return '${p.count} ${p.count == 1 ? unit : '${unit}s'}';
}

/// "7-day", "1-month" - the trial length as an adjective ("7-day free trial").
String trialDurationAdjective(StorePeriod period) {
  final p = _trialUnits(period);
  return '${p.count}-${_unitName(p.unit)}';
}

/// "$24.99/year", or "$59.99 every 6 months" for multi-unit periods.
String pricePerPeriodLabel(String price, StorePeriod period) {
  final unit = _unitName(period.unit);
  return period.count == 1
      ? '$price/$unit'
      : '$price every ${period.count} ${unit}s';
}

/// A free trial the store is offering *this* user on a subscription.
class FreeTrialOffer {
  const FreeTrialOffer({
    required this.trialPeriod,
    required this.recurringPrice,
    required this.recurringPeriod,
  });

  /// Total length of the free phase.
  final StorePeriod trialPeriod;

  /// The price charged once the trial ends, as [displayPriceFor] formats it.
  final String recurringPrice;

  /// How often [recurringPrice] is charged.
  final StorePeriod recurringPeriod;

  /// "7 days"
  String get durationLabel => trialDurationLabel(trialPeriod);

  /// "7-day"
  String get durationAdjective => trialDurationAdjective(trialPeriod);

  /// "$24.99/year"
  String get recurringPriceLabel =>
      pricePerPeriodLabel(recurringPrice, recurringPeriod);
}

/// The free trial to advertise for [product], or null when there is none.
///
/// Android only. Play returns a trial offer only to users who are eligible for
/// it, so its presence among the product's offers *is* the eligibility check;
/// this looks at the same offer [selectAndroidOffer] will buy, so the paywall
/// never promises a trial the purchase would not carry.
///
/// iOS returns null on purpose: StoreKit reports a product's introductory offer
/// whether or not this Apple ID can still redeem it (that needs a separate
/// async eligibility query), so the product info alone cannot justify showing
/// a trial.
///
/// Null too when either the trial or the recurring billing period cannot be
/// parsed - better no trial copy than wrong trial copy.
FreeTrialOffer? freeTrialFor(ProductCommon? product) {
  if (product is! ProductSubscriptionAndroid) return null;

  final offer = selectAndroidOffer(product.subscriptionOffers);
  if (offer == null || !offerHasFreeTrial(offer)) return null;

  final phases = offer.pricingPhasesAndroid!.pricingPhaseList;
  final trial = phases.first;
  final trialPeriod = parseStorePeriod(trial.billingPeriod);
  if (trialPeriod == null) return null;

  PricingPhaseAndroid? recurring;
  for (final phase in phases.reversed) {
    if (phase.priceAmountMicros != '0') {
      recurring = phase;
      break;
    }
  }
  if (recurring == null) return null;

  final recurringPeriod = parseStorePeriod(recurring.billingPeriod);
  if (recurringPeriod == null) return null;

  return FreeTrialOffer(
    trialPeriod: _times(trialPeriod, trial.billingCycleCount),
    recurringPrice: displayPriceFor(product),
    recurringPeriod: recurringPeriod,
  );
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

  final isReplacement =
      oldPurchaseToken != null &&
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
    ErrorCode.ItemUnavailable ||
    ErrorCode.SkuNotFound => 'This plan is not available right now',
    ErrorCode.NetworkError ||
    ErrorCode.ServiceError ||
    ErrorCode.ServiceTimeout =>
      'Could not reach the store. Check your connection and try again.',
    ErrorCode.BillingUnavailable || ErrorCode.IapNotAvailable =>
      'In-app purchases are not available on this device',
    ErrorCode.DeferredPayment ||
    ErrorCode.Pending => 'Your payment is pending approval',
    _ => error.message.isEmpty ? 'Purchase failed' : error.message,
  };
}

/// Whether an error means the user backed out, rather than something failing.
bool isUserCancellation(PurchaseError error) =>
    error.code == ErrorCode.UserCancelled;
