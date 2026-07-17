# Testing in-app purchases on iOS

`ios/Odyssey.storekit` is a local StoreKit configuration: three products that mirror
the real ones, so the purchase flow can be exercised in the Simulator without App
Store Connect, without a sandbox account, and without spending anything.

| Product ID | Type | Price |
|---|---|---|
| `odyssey_premium_monthly` | auto-renewing (group "Odyssey Premium") | $2.99 / month |
| `odyssey_premium_yearly` | auto-renewing (same group) | $24.99 / year |
| `odyssey_premium_lifetime` | non-consumable | $49.99 |

The prices and IDs match `lib/src/features/subscription/data/constants/billing_config.dart`.
If you change one, change the other.

## Run it from Xcode, not `flutter run`

The config is attached to the Runner scheme's **launch** action. Xcode applies it when
Xcode launches the app. `flutter run` builds with Xcode but then installs and launches
through `simctl` itself, so the scheme's launch action never runs and **the StoreKit
config is not applied** — products come back empty and the paywall looks broken.

```
open ios/Runner.xcworkspace
# pick an iOS Simulator, then Product > Run
```

Xcode's transaction inspector lives at **Debug > StoreKit > Manage Transactions** while
the app is running: refund, expire, or cancel a subscription there and the app sees it.

Do not pass `--dart-define=BILLING_TEST_MODE=true`. That swaps the product IDs for
`android.test.purchased`, which this config knows nothing about.

## What this can and cannot test

**Can:** products loading, the paywall, the purchase sheet, cancellation, `purchaseStream`
updates, `completePurchase`, restore, and every StoreKit error you can inject from
**Editor > Enable/Disable StoreKit errors** in the config file.

**Cannot: premium is never granted.** The app posts the transaction to
`POST /subscription/purchase/verify`, and the backend verifies it properly:

- The app runs StoreKit 2 (`in_app_purchase_storekit` has `_useStoreKit2 = true` by
  default), so `serverVerificationData` is a JWS.
- `AppleJwsVerifier` pins **Apple Root CA - G3** with `X509ChainTrustMode.CustomRootTrust`
  and deliberately excludes the machine trust store.
- StoreKit Testing signs transactions with a **locally generated certificate**, which
  cannot chain to Apple's root. The chain fails to build, verification returns null, and
  `SubscriptionService` records a failed `SubscriptionEvent` and returns
  `{"verified": false}`.

That is the backend working as designed — it fails closed, exactly as it should. Note the
purchase is still finished on-device (`completePurchase` runs regardless of the
verification result), so the app ends up on Free with an error, not stuck in a pending
loop.

## Testing the grant end to end

Local StoreKit cannot do it. Real options:

1. **Sandbox.** Sandbox transactions are signed by Apple's real certificates, so they
   verify against the existing backend with no changes. Needs the three products created
   in App Store Connect, a sandbox tester account, and a **physical device** — sandbox
   purchases do not work in the Simulator.
2. **A dev-only backend bypass.** Deliberately not built. It would have to be gated on
   the environment plus an explicit flag, and if that flag ever reached production
   anyone could grant themselves Premium for free.

## Note on Apple credentials

`APPLE_ISSUER_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY_PATH` are absent from the
backend `.env`, so `AppStoreServerClient` reports itself unconfigured and its
transaction-lookup path returns null.

This does **not** block real iOS purchases. StoreKit 2 sends a self-contained JWS that
`AppleJwsVerifier` validates from the certificate chain alone, needing no credentials.
Those keys are only needed for the App Store Server API — looking a transaction up by
id, which is the fallback for a receipt that is not a JWS.
