# 📋 Odyssey AdMob Setup — fill in the blanks, then hand this back

Ads are now wired into Odyssey for **free users only** (paid/premium users see
**zero** ads — every surface is gated behind the existing premium check).

You don't need to do anything to *test* — debug builds always use Google's
official **test ads**, so the app runs and shows ads right now. The values below
are only needed for a **production release** with your own real ads.

> ⚠️ **Never click your own live ads** on a real build — it can get your AdMob
> account suspended. That's exactly why debug/profile builds force test ads.

---

## How to get these values

1. Go to **https://apps.admob.com** → create (or open) your app.
2. **App ID** lives under **App settings** — it looks like `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (note the **`~`**).
3. **Ad unit IDs** live under **Ad units** — create one unit per format. Each looks like `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` (note the **`/`**).
4. Create a **separate AdMob app for Android and for iOS** if you ship both. If you're Android-only for now, just fill the Android section and leave iOS blank.

The ad formats in use: **Banner**, **Native (inline)**, **Interstitial**, **App Open**, and **Rewarded**. Create one ad unit of each type, per platform.

---

## 1️⃣ App IDs  → I'll paste these into the native files (AndroidManifest / Info.plist)

```
ANDROID_ADMOB_APP_ID = ca-app-pub-9242904787767394~5341675793
IOS_ADMOB_APP_ID     = ca-app-pub-9242904787767394~4028594127
```

## 2️⃣ Ad Unit IDs  → baked into `lib/src/core/config/admob_config.dart` (not secrets, so committed in code)

### Android
```
ADMOB_BANNER_AD_UNIT_ID_ANDROID       = ca-app-pub-9242904787767394/9610269465
ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID = ca-app-pub-9242904787767394/6984106128
ADMOB_REWARDED_AD_UNIT_ID_ANDROID     = ca-app-pub-9242904787767394/6521071698
ADMOB_APP_OPEN_AD_UNIT_ID_ANDROID     = ca-app-pub-9242904787767394/8479505259
ADMOB_NATIVE_AD_UNIT_ID_ANDROID       = ca-app-pub-9242904787767394/8955663340
```

### iOS  (leave blank if you're not shipping iOS yet)
```
ADMOB_BANNER_AD_UNIT_ID_IOS       = ca-app-pub-9242904787767394/1923351138
ADMOB_INTERSTITIAL_AD_UNIT_ID_IOS = ca-app-pub-9242904787767394/3603264319
ADMOB_REWARDED_AD_UNIT_ID_IOS     = ca-app-pub-9242904787767394/4209087752
ADMOB_APP_OPEN_AD_UNIT_ID_IOS     = ca-app-pub-9242904787767394/7166423589
ADMOB_NATIVE_AD_UNIT_ID_IOS       = ca-app-pub-9242904787767394/7642581676
```

## 3️⃣ (Optional) Test device IDs

If you want to see **test ads on a physical device even from your real ad
units** (safe to tap), run the app once, look in the logs for a line like
`Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("33BE2250B43..."))`,
and paste the ID(s) here:

```
ADMOB_TEST_DEVICE_IDS = <PASTE comma-separated, e.g. 33BE2250B43,9A1C... — optional>
```

---

## What happens with these (FYI — you don't need to do this, I will)

| Value | Goes into |
|---|---|
| `ANDROID_ADMOB_APP_ID` | `android/app/src/main/AndroidManifest.xml` (the `com.google.android.gms.ads.APPLICATION_ID` meta-data) |
| `IOS_ADMOB_APP_ID` | `ios/Runner/Info.plist` (`GADApplicationIdentifier`) |
| All ad unit IDs | `lib/src/core/config/admob_config.dart` constants (release builds only; debug uses test ads) |
| Test device IDs | `lib/src/core/config/admob_config.dart` (`testDeviceIds` constant) |

---

## Ad behaviour (the "aggressive" profile you chose)

All caps live in **one file** — `lib/src/features/ads/ad_constants.dart` — so we
can dial intensity up or down anytime without touching logic.

| Format | Where | Cadence |
|---|---|---|
| **App Open** | App-wide | On returning to the app after 30s+ in the background, + once shortly after launch (never over the splash/login). |
| **Interstitial** | On navigation | Every **3rd** screen push, min **45s** apart, never stacked with an app-open ad. |
| **Banner** | Bottom of Home, Notifications, Statistics, Achievements, Settings | Always visible while on screen. |
| **Native (inline)** | Home trips list | A native ad after every **4th** trip. |
| **Rewarded** | Year-in-Review paywall | Optional "watch a short ad to preview" — user-initiated only. |

### Want it more or less aggressive later?
Edit `ad_constants.dart`:
- `interstitialEveryNNavigations` (↓ = more often), `interstitialCooldown`
- `appOpenMinBackgroundDuration`
- `nativeAdEveryNItems` (↓ = more ads in lists)

---

## Compliance notes

- **AD_ID permission** — already added to the Android manifest (required for ads on Android 13+).
- **GDPR / consent** — Google's **UMP consent flow** is wired in. It's geography-aware: the consent form **only appears for users in regions that legally require it** (EEA/UK/etc). Everyone else loads ads immediately, no prompt. Set up your consent message/form in **AdMob → Privacy & messaging → GDPR** so the EEA form has content to show.
- **iOS App Tracking Transparency** — `NSUserTrackingUsageDescription` is in `Info.plist`. (Android-first today; the iOS keys are in place for when you ship it.)
- **iOS minimum** — `google_mobile_ads 8.0.0` needs iOS 13+. Bump the Podfile platform if you ship iOS.

---

## Quick checklist for going live
- [ ] Fill in the App IDs (section 1) and Android Ad Unit IDs (section 2).
- [ ] Set up the GDPR consent message in the AdMob dashboard.
- [ ] Link your app to AdMob and add a `app-ads.txt` to your domain (AdMob will prompt you).
- [ ] Build a **release** APK/AAB and confirm real ads fill.
- [ ] (iOS) Fill iOS App ID + unit IDs, bump Podfile to iOS 13+, configure ATT.
