# Subscription Testing Setup

## Google Play Test Configuration

### Test Accounts
1. Go to **Google Play Console** > **Settings** > **License testing**
2. Add Gmail addresses of testers
3. Licensed testers can make test purchases without being charged

### Internal Testing Track
1. Go to **Google Play Console** > Your App > **Testing** > **Internal testing**
2. Create a release and upload APK/AAB
3. Add testers by email or link
4. Testers install the app from the Play Store internal track

### Google Play Test Product IDs
These are built-in test product IDs that work without publishing:

| Product ID | Behavior |
|---|---|
| `android.test.purchased` | Always succeeds |
| `android.test.canceled` | Always cancels |
| `android.test.item_unavailable` | Item not found |
| `android.test.refunded` | Simulates refund |

> **Note:** Test product IDs don't trigger RTDN webhooks. Use licensed tester accounts with real product IDs for end-to-end testing.

### Testing Subscription Renewal
- Google Play accelerates renewals for test subscriptions:
  - Monthly = renews every 5 minutes
  - Yearly = renews every 30 minutes
- Subscriptions auto-cancel after 6 renewals
- Grace period is shortened to minutes

## Apple Test Configuration

### Sandbox Accounts
1. Go to **App Store Connect** > **Users and Access** > **Sandbox** > **Testers**
2. Create sandbox tester accounts
3. On device: **Settings** > **App Store** > **Sandbox Account**

### StoreKit Testing in Xcode
1. Create a StoreKit Configuration file in Xcode
2. Add products matching your App Store Connect products
3. Enable StoreKit testing in scheme editor
4. Test purchases locally without needing a server

### Apple Sandbox Renewal Schedule
- Monthly = renews every 3-5 minutes
- Yearly = renews every 1 hour
- Subscriptions auto-cancel after 6 renewals

## Testing Scenarios

### Happy Path
1. Purchase monthly subscription
2. Verify backend receives purchase and creates `SubscriptionEvent`
3. Verify user tier changes to Premium
4. Wait for renewal, verify `SubscriptionEvent` for renewal

### Payment Failure
1. Purchase subscription
2. In Play Console or App Store Connect, simulate payment failure
3. Verify grace period is set on user
4. Verify push notification is sent
5. Wait for grace period to expire, verify downgrade to Free

### Refund
1. Purchase subscription
2. In Play Console, issue refund
3. Verify voided purchase webhook arrives
4. Verify user is immediately downgraded to Free

### Cancellation
1. Purchase subscription
2. Cancel subscription in Play Store / Settings
3. Verify cancellation event is logged
4. Verify user keeps access until expiration
5. Verify downgrade after expiration

### Restore Purchases
1. Purchase subscription on device A
2. Install app on device B with same account
3. Trigger restore purchases
4. Verify subscription is restored

## Debug Tools

### Backend Logs
Check Serilog output for webhook processing:
```
grep "webhook" logs/odyssey-*.log
```

### Database Queries
Check subscription events:
```sql
SELECT * FROM subscription_events
ORDER BY created_at DESC
LIMIT 20;
```

Check user subscription state:
```sql
SELECT id, email, subscription_tier, subscription_plan,
       subscription_expires_at, google_play_purchase_token,
       apple_original_transaction_id, grace_period_ends_at
FROM users
WHERE subscription_tier = 'Premium';
```

### Webhook Health Check
```bash
curl https://your-api-domain.com/api/v1/webhooks/health
```

## Common Issues

### "User not found for purchase token"
The webhook arrived before the client completed verification. This is normal for `SUBSCRIPTION_PURCHASED` events - the client verification will link the user.

### Webhook returns 200 but no processing
Check the webhook verification token. The endpoint always returns 200 (to prevent retries) even when the token is invalid.

### Subscription not activating after purchase
1. Check if `verifyPurchase` API was called by the client
2. Check backend logs for verification errors
3. Verify the Google Play service account has proper permissions
4. Check if the product ID maps correctly to a subscription plan

### Grace period not working
1. Verify `GRACE_PERIOD_DAYS` environment variable is set
2. Check that the `GracePeriodEndsAt` field is being set on the user
3. The daily expiration job runs at 00:30 UTC - check if it's running

## Security Testing Checklist

- [ ] Webhook endpoint rejects requests without valid token
- [ ] Webhook endpoint returns 200 even on auth failure (prevents information leakage)
- [ ] Purchase verification actually calls Google Play API (not trusting client)
- [ ] Service account JSON is not accessible via web
- [ ] Webhook token uses constant-time comparison (prevents timing attacks)
- [ ] Database stores raw responses for audit trail
