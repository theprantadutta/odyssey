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

### 3. Enable Google Play Developer API

1. Go to **Google Cloud Console** > [APIs & Services](https://console.cloud.google.com/apis/library)
2. Search for **"Google Play Android Developer API"**
3. Click on it and press **Enable**
4. Wait for it to finish enabling (takes a few seconds)

> **Important:** This must be enabled in the **same Google Cloud project** that is linked to your Google Play Console developer account.

### 4. Create a Service Account

1. Go to **Google Cloud Console** > [IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. Click **"+ Create Service Account"** at the top
3. Fill in:
   - **Service account name:** `odyssey-play-billing`
   - **Service account ID:** will auto-fill as `odyssey-play-billing@your-project.iam.gserviceaccount.com`
   - **Description:** `Service account for Odyssey Google Play purchase verification and RTDN`
4. Click **"Create and Continue"**
5. **Skip the "Grant this service account access to project" step** — click **Continue** (permissions are granted in Google Play Console, not here)
6. **Skip the "Grant users access" step** — click **Done**

### 5. Create and Download the JSON Key

1. In the Service Accounts list, click on the service account you just created (`odyssey-play-billing@...`)
2. Go to the **"Keys"** tab
3. Click **"Add Key"** > **"Create new key"**
4. Select **JSON** format
5. Click **Create** — the JSON key file will download automatically
6. Rename it to `google-play-service-account.json`
7. Place it in your backend deployment directory (where your `.env` file is)
8. **Never commit this file to git** — add it to `.gitignore`

### 6. Link Google Cloud Project to Google Play Console

1. Go to **Google Play Console** > [Setup > API access](https://play.google.com/console/developers/api-access)
2. If you see "Link a Google Cloud project", click **"Link"** and select the Google Cloud project where you created the service account
3. If already linked, verify it shows the correct project name

### 7. Grant Service Account Permissions in Google Play Console

This is the critical step — the service account needs permissions **in Google Play Console**, not just in Google Cloud.

1. Go to **Google Play Console** > [Setup > API access](https://play.google.com/console/developers/api-access)
2. Scroll down to **"Service accounts"** section
3. Find your `odyssey-play-billing@...` service account and click **"Manage Play Console permissions"** (or "Grant access" if it's new)
4. On the permissions page:
   - **Account permissions tab:** You can leave defaults
   - **App permissions tab:** Click **"Add app"** and select the Odyssey app
5. Under the app permissions, enable these:
   - **"View financial data, orders, and cancellation survey responses"** — required to read subscription status
   - **"Manage orders and subscriptions"** — required to verify purchases via the API
6. Click **"Invite user"** / **"Save changes"**
7. **Wait 24-48 hours** — Google Play Console permissions can take time to propagate. Purchase verification may fail until then.

### 8. Grant Pub/Sub Publish Permission (for RTDN)

Google Play needs permission to publish to your Pub/Sub topic.

1. Go to **Google Cloud Console** > [Pub/Sub > Topics](https://console.cloud.google.com/cloudpubsub/topic/list)
2. Click on your `odyssey-play-billing` topic
3. In the info panel on the right, click **"View Permissions"** (or go to the **Permissions** tab)
4. Click **"Add Principal"**
5. Add the principal: `google-play-developer-notifications@system.gserviceaccount.com`
6. Assign the role: **Pub/Sub Publisher**
7. Click **Save**

> This is a Google-managed service account that Google Play uses to send RTDN notifications to your topic.

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
- **Wait 24-48 hours** after granting Play Console permissions — they take time to propagate
- Verify the service account JSON file exists at the configured path
- Verify the **Google Play Android Developer API** is enabled in Google Cloud Console
- Check that the service account has **"View financial data"** and **"Manage orders and subscriptions"** permissions in **Google Play Console** (not just Google Cloud IAM)
- Ensure the Google Cloud project linked in Play Console is the same one where the service account lives
- Ensure the package name matches exactly (`com.pranta.odyssey`)
- Check backend logs for detailed error messages

### RTDN notifications not arriving
- Verify `google-play-developer-notifications@system.gserviceaccount.com` has **Pub/Sub Publisher** role on your topic
- Verify the Pub/Sub push subscription endpoint URL is publicly accessible (HTTPS required)
- Check the Pub/Sub subscription in Google Cloud Console for undelivered messages or errors
- Verify the topic name in Google Play Console matches exactly: `projects/YOUR_PROJECT_ID/topics/odyssey-play-billing`

### User not found for purchase token
- The user must complete a purchase through the app first (which stores `GooglePlayPurchaseToken`)
- For new purchases, the webhook may arrive before the client verification completes - this is normal

## Security Best Practices

- Never expose the webhook verification token
- Store service account credentials outside source control
- Use HTTPS for all webhook endpoints
- Monitor webhook processing logs for anomalies
- Rotate the webhook verification token periodically
