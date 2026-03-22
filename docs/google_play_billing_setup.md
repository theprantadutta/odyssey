# Google Play Billing Setup for Odyssey

## Product IDs

| Product ID | Type | Description |
|---|---|---|
| `odyssey_premium_monthly` | Subscription | Premium Monthly |
| `odyssey_premium_yearly` | Subscription | Premium Yearly |
| `odyssey_premium_lifetime` | In-App Product | Premium Lifetime |

## Google Play Console Configuration

### 1. Create Subscriptions
1. Go to **Google Play Console** > Your App > **Monetize** > **Subscriptions**
2. Create a subscription group called "Odyssey Premium"
3. Add base plans:
   - `odyssey_premium_monthly` - Monthly auto-renewing
   - `odyssey_premium_yearly` - Yearly auto-renewing
4. For lifetime purchase, go to **In-app products** and create `odyssey_premium_lifetime`

### 2. Set Up Real-Time Developer Notifications (RTDN)

RTDN uses Google Cloud Pub/Sub to push subscription events to your backend.

1. **Create a Pub/Sub topic** in Google Cloud Console:
   - Go to **Cloud Pub/Sub** > **Topics** > **Create Topic**
   - Name: `odyssey-play-billing`

2. **Create a Pub/Sub subscription** (push type):
   - Go to the topic > **Subscriptions** > **Create Subscription**
   - Delivery type: **Push**
   - Endpoint URL: `https://your-api-domain.com/api/v1/webhooks/google-play?token=YOUR_WEBHOOK_TOKEN`
   - Set appropriate acknowledgement deadline (e.g., 60 seconds)

3. **Link to Google Play Console**:
   - Go to **Google Play Console** > Your App > **Monetize** > **Monetization Setup**
   - Under "Real-time developer notifications", enter the full Pub/Sub topic name:
     `projects/your-project-id/topics/odyssey-play-billing`

### 3. Google Cloud Service Account

1. Go to **Google Cloud Console** > **IAM & Admin** > **Service Accounts**
2. Create a service account (e.g., `odyssey-play-billing@your-project.iam.gserviceaccount.com`)
3. Grant the role: **Android Publisher** (or custom role with `androidpublisher.purchases.*`)
4. Create and download a JSON key file
5. Place the key file as `google-play-service-account.json` in your backend deployment
6. In **Google Play Console** > **Settings** > **API Access**, grant the service account access

## Environment Variables

```env
# Path to the service account JSON key file
GOOGLE_PLAY_SERVICE_ACCOUNT=google-play-service-account.json

# Your app's package name
GOOGLE_PLAY_PACKAGE_NAME=com.pranta.odyssey

# Token for verifying Pub/Sub webhook authenticity
GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN=<generate-a-secure-random-token>

# Grace period for payment failures (days)
GRACE_PERIOD_DAYS=3
```

## Production Deployment Checklist

- [ ] Service account JSON key deployed securely (not in source control)
- [ ] `GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN` set to a strong random value
- [ ] Pub/Sub push endpoint URL is correct and accessible
- [ ] Service account has Android Publisher API access
- [ ] RTDN topic linked in Google Play Console
- [ ] Test notification sent successfully from Play Console
- [ ] Webhook health check returns 200: `GET /api/v1/webhooks/health`

## Troubleshooting

### Webhook not receiving notifications
- Verify the Pub/Sub subscription endpoint URL is publicly accessible
- Check that the `?token=` query parameter matches `GOOGLE_PLAY_PUBSUB_VERIFICATION_TOKEN`
- Ensure the push subscription is active in Google Cloud Console
- Check Pub/Sub dead-letter queue for failed deliveries

### Purchase verification failing
- Verify the service account JSON file exists at the configured path
- Check that the service account has `androidpublisher.purchases.get` permission
- Ensure the package name matches exactly
- Check backend logs for detailed error messages

### User not found for purchase token
- The user must complete a purchase through the app first (which stores `GooglePlayPurchaseToken`)
- For new purchases, the webhook may arrive before the client verification completes - this is normal

## Security Best Practices

- Never expose the webhook verification token
- Store service account credentials outside source control
- Use HTTPS for all webhook endpoints
- Monitor webhook processing logs for anomalies
- Rotate the webhook verification token periodically
