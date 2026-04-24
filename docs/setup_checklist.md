# Odyssey Subscription Setup Checklist

## Prerequisites

- [ ] Google Play Console developer account
- [ ] Apple Developer account
- [ ] Google Cloud Platform project
- [ ] Backend server with HTTPS

## Step 1: Google Play Setup

- [ ] Create subscription products in Google Play Console
  - [ ] `odyssey_premium_monthly`
  - [ ] `odyssey_premium_yearly`
  - [ ] `odyssey_premium_lifetime` (as in-app product)
- [ ] Create Google Cloud service account with Android Publisher API access
- [ ] Download service account JSON key
- [ ] Set up Cloud Pub/Sub topic for RTDN
- [ ] Create push subscription pointing to webhook endpoint
- [ ] Link Pub/Sub topic in Google Play Console monetization settings

## Step 2: Apple App Store Setup

- [ ] Create subscription products in App Store Connect
  - [ ] `odyssey_premium_monthly`
  - [ ] `odyssey_premium_yearly`
  - [ ] `odyssey_premium_lifetime` (as non-consumable)
- [ ] Create subscription group "Odyssey Premium"
- [ ] Configure App Store Server Notifications V2
  - [ ] Set webhook URL to `https://your-api-domain.com/api/v1/webhooks/apple`
  - [ ] Select Sandbox and Production environments

## Step 3: Backend Configuration

- [ ] Deploy `google-play-service-account.json` to server
- [ ] Set environment variables:

| Variable | Description |
|---|---|
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Path to service account JSON |
| `GOOGLE_PLAY_PACKAGE_NAME` | `com.pranta.odyssey` |
| `GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN` | Secure random token |
| `APPLE_BUNDLE_ID` | `com.pranta.odyssey` |
| `APPLE_ENVIRONMENT` | `Production` or `Sandbox` |
| `GRACE_PERIOD_DAYS` | `3` (default) |

- [ ] Run database migration: `dotnet ef database update`
- [ ] Verify webhook health: `GET /api/v1/webhooks/health`

## Step 4: Testing

- [ ] Set up test accounts in Google Play Console
- [ ] Set up sandbox accounts in App Store Connect
- [ ] Upload app to internal testing track (Google Play)
- [ ] Upload app to TestFlight (App Store)
- [ ] Test full purchase flow on Android
- [ ] Test full purchase flow on iOS
- [ ] Verify `SubscriptionEvent` records are created in database
- [ ] Test webhook delivery with Google Play test notification
- [ ] Test webhook delivery with Apple test notification

## Quick Links

- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Google Cloud Console](https://console.cloud.google.com)
- [Google Play Billing Docs](https://developer.android.com/google/play/billing)
- [App Store Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications)
