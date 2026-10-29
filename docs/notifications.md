# Push notifications

How notifications work end to end, what changed on 29 Oct 2026, and what a
macOS session must do to finish and verify the iOS side. The Android side was
built and checked on Windows; iOS could not be.

## How it fits together

```
backend event / Hangfire job
  -> IPushNotificationService.SendToUsersAsync  (writes history, applies prefs)
  -> FCM (HTTP v1, FirebaseAdmin)                (per user, badge = unread count)
  -> device
       foreground: NotificationService shows it locally (JSON payload)
       tap:        NotificationService -> auth_provider._handleNotificationTap -> router
```

- **Channel:** `odyssey_notifications`, created in
  `lib/src/core/services/notification_service.dart`, named in
  `AndroidManifest.xml` and in every FCM message from
  `FcmNotificationService.CreateMulticastMessage`.
- **Small icon (Android):** `@drawable/ic_stat_notification`, white on
  transparent, generated from the launcher's monochrome layer.
- **Device registration:** `POST /api/v1/devices/register` with `fcm_token`,
  `platform`, `utc_offset_minutes`. One live row per token (unique index).
  `DELETE /api/v1/devices/{token}` on sign-out.
- **Tap routing:** `data.type` (+ `trip_id` / `invite_code`) in
  `auth_provider.dart` `_handleNotificationTap`.
- **Guests** never register a device, never see the bell or the notification
  screens, and are never asked for permission.

## Types and when they go out

| type | trigger | preference |
|---|---|---|
| `trip_invite`, `invite_accepted`, `invite_declined`, `share_revoked`, `permission_changed` | sharing actions | Invites & sharing |
| `invite_expiring` | hourly job, once, when an invite enters its last day | Invites & sharing |
| `activity_added`, `document_added`, `memory_added`, `expense_added` | a collaborator adds to a shared trip | Shared trip activity |
| `trip_reminder` | hourly job: 09:00 local the day before, 08:00 local on the day | Trip reminders |
| `achievement_earned` | achievement checks, via the dispatcher | Achievements |
| `payment_failure` | store webhooks | always |

Quiet hours defer any of these to the end of the quiet period. Local time comes
from the offset the device reports on registration; a user with no device gets
UTC.

## What changed on 29 Oct 2026

Backend (`odyssey-backend`):
- Firebase is created at startup (`FirebaseAppProvider`); before, pushes were
  skipped after every restart until someone signed in with Google or Apple.
- Multi-user sends honour category toggles and quiet hours.
- Only tokens FCM says are dead are deleted (not every `INVALID_ARGUMENT`).
- Unique index on `user_devices.fcm_token`; migration
  `NotificationDeliveryFixes` (applied to production 29 Oct) also removed
  existing duplicates and added `utc_offset_minutes`.
- Reminders hourly at local hours, with history-based de-duplication;
  invite-expiring once; daily history clean-up (read > 90 days, any > 1 year).
- Achievements go through the dispatcher; transient FCM failures are retried by
  Hangfire without duplicating history; badge = unread count; batches of 500.

App (`odyssey`):
- Taps are routed (they were not: `initialize` returned before storing the
  callbacks), including the tap that launches the app.
- The token is cleared on sign-out and forgotten on session expiry; push set-up
  also runs on an offline start.
- New Android small icon; JSON local payloads; unread dot on the home bell.
- iOS: `remote-notification` background mode added; the app's own
  `MessagingDelegate` removed so FlutterFire's is the only one.

## macOS session: finish and verify iOS

These need Xcode, an Apple developer account and a real iPhone - the simulator
cannot receive remote pushes from FCM on most setups.

1. **Firebase config file.** `ios/Runner/GoogleService-Info.plist` is
   gitignored and missing from fresh clones. Download it from Firebase console
   → Project settings → iOS app `com.pranta.odyssey` and put it in
   `ios/Runner/`. Without it `FirebaseApp.configure()` in `AppDelegate.swift`
   crashes on launch.
2. **APNs key in Firebase.** Firebase console → Project settings → Cloud
   Messaging → Apple app configuration: an **APNs Authentication Key** (.p8)
   with its Key ID and Team ID must be uploaded. Without it FCM cannot deliver
   to iOS at all, and nothing in the app or backend reports why. Create one at
   developer.apple.com → Keys → "Apple Push Notifications service" if missing.
3. **Capabilities in Xcode** (Runner target → Signing & Capabilities):
   - *Push Notifications* - present (`Runner.entitlements` has
     `aps-environment`; Xcode switches it to production when archiving with a
     distribution profile).
   - *Background Modes* → tick **Remote notifications**. `Info.plist` now
     declares it; Xcode should show it ticked - if not, tick it so the
     capability and the plist agree.
   - The App ID on developer.apple.com must have Push Notifications enabled,
     and the provisioning profiles regenerated after enabling it.
4. **Build and run on a device:** `flutter run --release -d <iphone>` (release
   talks to production; profile/debug talk to `DEV_URL`).
5. **Verify, in order** - each step depends on the one before:
   1. Sign in, add a trip, wait for the notification explainer sheet on the
      Trips tab, allow notifications.
   2. Confirm registration reached the server: a row for the user in
      `user_devices` with `platform = 'iOS'` and a `utc_offset_minutes`.
   3. Send a test push: Firebase console → Messaging → "Send test message" to
      the FCM token (log line `FCM Token obtained` prints the first 20 chars;
      the full token is in `user_devices`). Check it arrives with the app
      **in the background**, **killed**, and **open** (open = shown by
      `NotificationService` as a local notification).
   4. Tap each of those: it must open the app on the right screen. Use a
      payload with `type = trip_reminder` and a real `trip_id` to see routing
      to the trip.
   5. Trigger a real one: share a trip with a second account and accept the
      invite - the owner gets `invite_accepted`.
   6. Badge: with unread notifications the app icon badge should show the
      unread count, not 1.
   7. Sign out: the `user_devices` row disappears; pushes to that account stop.
6. **If tokens never refresh into Dart** (`onTokenRefresh` silent), check that
   no other code sets `Messaging.messaging().delegate`; FlutterFire must own it.
7. **App Store build:** archive in Xcode, confirm the archived app's
   entitlements show `aps-environment = production`
   (`codesign -d --entitlements :- Runner.app`).

## Backend checks after any deploy

- Startup log must not contain `FATAL: Firebase could not be initialized`.
- Hangfire recurring jobs present: `trip-reminders`, `invite-expiry-reminders`,
  `notification-history-cleanup`; the old `trip-reminders-tomorrow` /
  `trip-reminders-today` gone.
- A push logs `Sent notification. Success: N` - `Firebase Messaging not
  configured` means credentials are missing.
