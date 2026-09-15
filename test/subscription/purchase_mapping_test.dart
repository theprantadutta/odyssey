import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/subscription/data/constants/billing_config.dart';
import 'package:odyssey/src/features/subscription/data/services/purchase_mapping.dart';

PurchaseAndroid _android({
  String productId = ProductIds.monthlySubscription,
  String? transactionId = 'GPA.1234-5678-9012-34567',
  String id = 'GPA.1234-5678-9012-34567',
  String? purchaseToken = 'play-token',
  PurchaseState state = PurchaseState.Purchased,
  bool? isAcknowledged,
}) {
  return PurchaseAndroid(
    id: id,
    isAutoRenewing: true,
    productId: productId,
    purchaseState: state,
    purchaseToken: purchaseToken,
    quantity: 1,
    store: IapStore.Google,
    transactionDate: 1700000000000,
    transactionId: transactionId,
    isAcknowledgedAndroid: isAcknowledged,
  );
}

PurchaseIOS _ios({
  String productId = ProductIds.yearlySubscription,
  String transactionId = '2000000123456789',
  String? purchaseToken = 'header.payload.signature',
  PurchaseState state = PurchaseState.Purchased,
}) {
  return PurchaseIOS(
    id: transactionId,
    isAutoRenewing: true,
    productId: productId,
    purchaseState: state,
    purchaseToken: purchaseToken,
    quantity: 1,
    store: IapStore.Apple,
    transactionDate: 1700000000000,
    transactionId: transactionId,
  );
}

PricingPhaseAndroid _phase({
  required String micros,
  required String formatted,
  int recurrenceMode = 2,
  String period = 'P1M',
  int cycles = 1,
}) {
  return PricingPhaseAndroid(
    billingCycleCount: cycles,
    billingPeriod: period,
    formattedPrice: formatted,
    priceAmountMicros: micros,
    priceCurrencyCode: 'USD',
    recurrenceMode: recurrenceMode,
  );
}

SubscriptionOffer _offer({
  required String id,
  String? basePlanId = 'premium-monthly',
  String? offerToken = 'offer-token',
  List<PricingPhaseAndroid>? phases,
}) {
  return SubscriptionOffer(
    basePlanIdAndroid: basePlanId,
    displayPrice: r'$2.99',
    id: id,
    offerTokenAndroid: offerToken,
    price: 2.99,
    pricingPhasesAndroid: phases == null
        ? null
        : PricingPhasesAndroid(pricingPhaseList: phases),
    type: DiscountOfferType.Introductory,
  );
}

ProductSubscriptionAndroid _subscriptionProduct({
  String displayPrice = 'Free',
  required List<SubscriptionOffer> offers,
}) {
  return ProductSubscriptionAndroid(
    currency: 'USD',
    description: 'Odyssey Premium',
    displayPrice: displayPrice,
    id: ProductIds.monthlySubscription,
    nameAndroid: 'Odyssey Premium Monthly',
    subscriptionOffers: offers,
    title: 'Odyssey Premium Monthly',
  );
}

void main() {
  group('purchaseIdentity', () {
    test('uses the Play order id on Android', () {
      expect(purchaseIdentity(_android()), 'GPA.1234-5678-9012-34567');
    });

    test('falls back to the purchase token when the order id is null', () {
      // The order id is null while a Play purchase is still pending.
      final purchase = _android(transactionId: null, id: 'play-token');
      expect(purchaseIdentity(purchase), 'play-token');
    });

    test('uses the StoreKit transaction id on iOS', () {
      expect(purchaseIdentity(_ios()), '2000000123456789');
    });

    test('returns null when there is nothing usable', () {
      final purchase = _android(transactionId: null, id: '', purchaseToken: null);
      expect(purchaseIdentity(purchase), isNull);
    });
  });

  group('backendPayloadFor', () {
    test('sends the Play purchase token as receipt data on Android', () {
      final payload = backendPayloadFor(_android())!;

      expect(payload['platform'], 'android');
      expect(payload['product_id'], ProductIds.monthlySubscription);
      expect(payload['receipt_data'], 'play-token');
      expect(payload['purchase_token'], 'play-token');
      expect(payload['transaction_id'], 'GPA.1234-5678-9012-34567');
    });

    test('sends the StoreKit 2 JWS as receipt data on iOS', () {
      final payload = backendPayloadFor(_ios())!;

      expect(payload['platform'], 'ios');
      expect(payload['receipt_data'], 'header.payload.signature');
      expect(payload['transaction_id'], '2000000123456789');
    });

    test('returns null when the purchase carries no token', () {
      expect(backendPayloadFor(_android(purchaseToken: null)), isNull);
      expect(backendPayloadFor(_android(purchaseToken: '')), isNull);
    });

    test('keeps the key names the pre-migration client used', () {
      expect(
        backendPayloadFor(_android())!.keys.toSet(),
        {
          'product_id',
          'transaction_id',
          'platform',
          'receipt_data',
          'purchase_token',
        },
      );
    });
  });

  group('classifyVerifyResponse', () {
    test('grants on verified: true', () {
      expect(
        classifyVerifyResponse({'verified': true}),
        VerifyOutcome.granted,
      );
    });

    test('is transient when the backend could not be reached', () {
      expect(classifyVerifyResponse(null), VerifyOutcome.transient);
    });

    test('is transient for a retryable error code', () {
      expect(
        classifyVerifyResponse({
          'verified': false,
          'error': 'PURCHASE_VERIFICATION_UNAVAILABLE: Google Play unreachable',
        }),
        VerifyOutcome.transient,
      );
      expect(
        classifyVerifyResponse({
          'verified': false,
          'error': 'PURCHASE_PENDING: awaiting payment',
        }),
        VerifyOutcome.transient,
      );
    });

    test('rejects an explicit false with no retryable code', () {
      expect(
        classifyVerifyResponse({'verified': false}),
        VerifyOutcome.rejected,
      );
      expect(
        classifyVerifyResponse({
          'verified': false,
          'error': 'PURCHASE_INVALID: signature mismatch',
        }),
        VerifyOutcome.rejected,
      );
    });
  });

  group('selectAndroidOffer', () {
    test('prefers a free-trial offer', () {
      final trial = _offer(
        id: 'free-trial',
        phases: [
          _phase(micros: '0', formatted: 'Free', recurrenceMode: 2),
          _phase(micros: '2990000', formatted: r'$2.99', recurrenceMode: 1),
        ],
      );
      final base = _offer(id: 'premium-monthly');

      expect(selectAndroidOffer([base, trial])?.id, 'free-trial');
    });

    test('falls back to the base plan when there is no trial', () {
      final promo = _offer(id: 'promo-code');
      final base = _offer(id: 'premium-monthly');

      expect(selectAndroidOffer([promo, base])?.id, 'premium-monthly');
    });

    test('falls back to the first offer with a token', () {
      final noToken = _offer(id: 'a', basePlanId: 'x', offerToken: null);
      final other = _offer(id: 'b', basePlanId: 'x');

      expect(selectAndroidOffer([noToken, other])?.id, 'b');
    });

    test('returns null when nothing is purchasable', () {
      expect(selectAndroidOffer([]), isNull);
      expect(
        selectAndroidOffer([_offer(id: 'a', offerToken: null)]),
        isNull,
      );
    });

    test('does not treat a permanently free plan as a trial', () {
      // recurrenceMode 1 is infinite recurring - free forever, not a trial.
      final freePlan = _offer(
        id: 'free-forever',
        phases: [_phase(micros: '0', formatted: 'Free', recurrenceMode: 1)],
      );
      expect(offerHasFreeTrial(freePlan), isFalse);
    });
  });

  group('displayPriceFor', () {
    test('shows the recurring price, not "Free", for a trial subscription', () {
      final product = _subscriptionProduct(
        displayPrice: 'Free',
        offers: [
          _offer(
            id: 'free-trial',
            phases: [
              _phase(micros: '0', formatted: 'Free'),
              _phase(micros: '2990000', formatted: r'$2.99', recurrenceMode: 1),
            ],
          ),
        ],
      );

      expect(displayPriceFor(product), r'$2.99');
    });

    test('falls back to displayPrice when there are no pricing phases', () {
      final product = _subscriptionProduct(
        displayPrice: r'$2.99',
        offers: [_offer(id: 'premium-monthly')],
      );

      expect(displayPriceFor(product), r'$2.99');
    });
  });

  group('account tokens', () {
    const uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

    test('Apple accepts only a UUID', () {
      // The OpenIAP Apple module throws on a non-UUID appAccountToken.
      expect(appleAccountTokenFor(uuid), uuid);
      expect(appleAccountTokenFor('user-42'), isNull);
      expect(appleAccountTokenFor(''), isNull);
      expect(appleAccountTokenFor(null), isNull);
    });

    test('Android accepts any non-empty string', () {
      expect(androidAccountIdFor('user-42'), 'user-42');
      expect(androidAccountIdFor(uuid), uuid);
      expect(androidAccountIdFor(''), isNull);
      expect(androidAccountIdFor(null), isNull);
    });
  });

  group('buildPurchaseProps', () {
    const uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

    test('uses the in-app shape for the lifetime product', () {
      final props = buildPurchaseProps(
        productId: ProductIds.lifetimePurchase,
        userId: uuid,
      ).toJson();

      expect(props['type'], ProductQueryType.InApp.toJson());
      expect(props.containsKey('requestPurchase'), isTrue);

      final google = props['requestPurchase']['google'] as Map<String, dynamic>;
      expect(google['skus'], [ProductIds.lifetimePurchase]);
      expect(google['obfuscatedAccountId'], uuid);
    });

    test('uses the subs shape and an offer token for subscriptions', () {
      final props = buildPurchaseProps(
        productId: ProductIds.monthlySubscription,
        userId: uuid,
        androidOfferToken: 'offer-token',
      ).toJson();

      expect(props['type'], ProductQueryType.Subs.toJson());

      final google =
          props['requestSubscription']['google'] as Map<String, dynamic>;
      expect(google['subscriptionOffers'], [
        {'offerToken': 'offer-token', 'sku': ProductIds.monthlySubscription},
      ]);
      expect(google['purchaseToken'], isNull);
      expect(google['subscriptionProductReplacementParams'], isNull);
    });

    test('omits a non-UUID appAccountToken but keeps it for Play', () {
      final props = buildPurchaseProps(
        productId: ProductIds.monthlySubscription,
        userId: 'user-42',
        androidOfferToken: 'offer-token',
      ).toJson();

      final apple = props['requestSubscription']['apple'] as Map<String, dynamic>;
      final google =
          props['requestSubscription']['google'] as Map<String, dynamic>;

      expect(apple['appAccountToken'], isNull);
      expect(google['obfuscatedAccountId'], 'user-42');
    });

    test('sets replacement params when switching plans on Android', () {
      final props = buildPurchaseProps(
        productId: ProductIds.yearlySubscription,
        userId: uuid,
        androidOfferToken: 'offer-token',
        oldPurchaseToken: 'old-token',
        oldProductId: ProductIds.monthlySubscription,
      ).toJson();

      final google =
          props['requestSubscription']['google'] as Map<String, dynamic>;

      expect(google['purchaseToken'], 'old-token');
      expect(
        google['subscriptionProductReplacementParams'],
        {
          'oldProductId': ProductIds.monthlySubscription,
          'replacementMode':
              SubscriptionReplacementModeAndroid.WithTimeProration.toJson(),
        },
      );
    });

    test('does not build a replacement when the plan is unchanged', () {
      final props = buildPurchaseProps(
        productId: ProductIds.monthlySubscription,
        androidOfferToken: 'offer-token',
        oldPurchaseToken: 'old-token',
        oldProductId: ProductIds.monthlySubscription,
      ).toJson();

      final google =
          props['requestSubscription']['google'] as Map<String, dynamic>;

      expect(google['purchaseToken'], isNull);
      expect(google['subscriptionProductReplacementParams'], isNull);
    });
  });

  group('isConsumableProduct', () {
    test('nothing in Odyssey is consumable', () {
      for (final id in ProductIds.all) {
        expect(isConsumableProduct(id), isFalse, reason: id);
      }
    });
  });

  group('purchaseErrorMessage', () {
    test('reports a cancellation plainly', () {
      final error = PurchaseError(
        code: ErrorCode.UserCancelled,
        message: 'cancelled',
      );
      expect(purchaseErrorMessage(error), 'Purchase was canceled');
      expect(isUserCancellation(error), isTrue);
    });

    test('points an already-owned product at Restore Purchases', () {
      final error = PurchaseError(
        code: ErrorCode.AlreadyOwned,
        message: 'owned',
      );
      expect(purchaseErrorMessage(error), contains('Restore Purchases'));
    });

    test('falls back to the plugin message for an unmapped code', () {
      // PurchaseError.code is nullable.
      final error = PurchaseError(message: 'something specific went wrong');
      expect(purchaseErrorMessage(error), 'something specific went wrong');
      expect(isUserCancellation(error), isFalse);
    });
  });
}
