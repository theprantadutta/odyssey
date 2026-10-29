# Store screenshots

How the store screenshot sets are made, so any session can redo them. The
Android sets were rebuilt on 29 Oct 2026 for 3.1.0 (Windows, real devices).
The App Store sets are still the 6 Oct ones and need the same treatment on a
Mac — see [App Store (macOS)](#app-store-macos).

## What exists

| Folder | Store slot | Size | Slides |
|---|---|---|---|
| `play_store_screenshots/` | Play phone | 1080 × 1920 | 8 |
| `play_store_screenshots_tablet_7in/` | Play 7-inch tablet | 1080 × 1920 | 8 |
| `play_store_screenshots_tablet_10in/` | Play 10-inch tablet | 2160 × 3840 | 8 |
| `app_store_screenshots/` | App Store iPhone 6.5" | 1284 × 2778 | 10 (6 Oct, old copy) |
| `ipad_store_screenshots/` | App Store iPad 13" | 2064 × 2752 | 10 (6 Oct, old copy) |

Tablet sizes copy The Accountant's Play setup
(`the-accountant/the_accountant/play_store_screenshots_tablet_*`), which Play
accepted. Both are 9:16 portrait.

Previous Play phone set: `store_screenshots/previous/play_store_screenshots_2026-10-06/`.

## The slides

Defined once in `store_screenshots/composer/build.py` (`SLIDES`). Every set
uses the same eight, in this order:

| # | File | Headline | Screen | Background |
|---|---|---|---|---|
| 1 | `01-every-trip-one-place` | Every trip, one place. | Home | ink |
| 2 | `02-your-next-trip-in-seconds` | Your next trip, in seconds. | "Where to next?" onboarding, filled in | lime |
| 3 | `03-plans-that-hold-up` | Plans that hold up. | Trip → Plan | paper |
| 4 | `04-packed-verified` | Packed. Verified. | Trip → Packing | ink |
| 5 | `05-any-currency-one-budget` | Know where it went. | Trip → Spend | lime |
| 6 | `06-every-place-pinned` | Every place, pinned. | Trip → Map + Memories (two devices) | paper |
| 7 | `07-your-travel-wallet` | Tickets, close at hand. | Trip → Documents | ink |
| 8 | `08-everything-in-one-trip` | Everything, in one trip. | Trip → Overview + feature chips | lime |

Copy rules: every claim must be true of the build. "No account needed" is
guest mode (3.1.0+). Don't show the world map: it is Pro-only and the demo
account is free, so it renders the paywall.

The look comes from the Odyssey Claude Design project
(`claude.ai/design/p/e05c70ae-facd-4490-87b4-7ff4fb2aa8db`, file
`Play Store Screenshots.dc.html`): ink `#0A0B0D` / lime `#D6FF3D` / paper
`#F2F2EF`, Space Grotesk 700 headlines at 100px, Manrope 500 body at 36px, the
capture in a dark frame bleeding off the bottom. `build.py` reproduces it in
plain HTML so it can run offline from Claude Design.

## Regenerating

```
python store_screenshots/composer/build.py                      # all three sets
python store_screenshots/composer/build.py play_store_screenshots   # one set
```

Needs Python with nothing extra, and Chrome at
`C:\Program Files\Google\Chrome\Application\chrome.exe` (change `CHROME` on
other machines). Fonts load from Google Fonts, so it needs a connection. The
10-inch set is the 7-inch page rendered at device scale 2.

To change copy, edit `SLIDES`. To change which part of a capture shows, edit
`CROP` (raw pixels cut from the top — used so trip tabs open on the stats row
instead of repeating the cover photo).

## Capturing (Android)

Raw captures live in `store_screenshots/raw/android_phone/` and
`store_screenshots/raw/android_tablet/`, one PNG per screen, named as in the
table above (`home`, `onboarding`, `plan`, `packing`, `spend`, `tripmap`,
`memories`, `documents`, `overview`, plus `trips`, unused).

Devices used:

| Device | adb serial | Screen |
|---|---|---|
| Galaxy A24 (SM-A245F) | `RR8W901JDRL` | 1080 × 2340 |
| Galaxy Tab A9 (SM-X115) | `R83X309RLNR` | 800 × 1340 |

Always pass `-s <serial>`: a realme phone is often connected too and must be
left alone.

Steps:

1. **Build and install a release APK** — `flutter build apk --release`, then
   `adb -s <serial> install -r build/app/outputs/flutter-apk/app-release.apk`.
   Release builds talk to production (`PROD_URL`); debug/profile builds talk to
   `DEV_URL` (the local backend). A profile build is signed with the debug key,
   so it cannot install over a release build without uninstalling first.
2. **Sign in with Google as John Doe** (`realjohndoe276@gmail.com`, already on
   both devices). That account has the four sample trips. Use **New York City
   Exploration** — it has photos, documents, plans and spend.
   - If Google sign-in fails with `UNREGISTERED_ON_API_CONSOLE` in logcat, the
     APK's signing certificate isn't registered in Firebase. Add its SHA-1 in
     Firebase → Project settings → com.pranta.odyssey → Add fingerprint.
     Registered on 29 Oct: upload key `FD:80:0C:FC:…:69:37` and the Windows
     debug key `B7:B0:D5:B2:…:EB:58`. Get a build's SHA-1 with
     `apksigner verify --print-certs <apk>`.
3. **Onboarding** appears on first sign-in per device. Type `Lisbon`, pick
   11–18 Nov, capture, then **Skip for now** (never Create — it would add a
   trip to the demo account).
4. **Walkthrough overlays** appear the first time on Trips and on trip detail —
   tap Skip before capturing.
5. **Capture** with `adb -s <serial> exec-out screencap -p > name.png`.
   Tapping a trip tab scrolls the page, which moves the tab bar; re-check
   positions with a screenshot rather than reusing coordinates.

Samsung ignores Android's status-bar demo mode
(`com.android.systemui.demo`), so captures keep the real status bar, as the
previous set did.

## App Store (macOS)

Not done yet. To match the Android sets:

1. Run the app on simulators sized for the slots already in use — iPhone 6.5"
   (1284 × 2778, e.g. iPhone 11 Pro Max / XS Max class) and iPad 13"
   (2064 × 2752, iPad Pro 13-inch M4). The 6.9" slot (1320 × 2868) is the one
   App Store Connect now asks for first; 6.5" is still accepted.
2. Clean the status bar before capturing:
   `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`
3. Sign in as John Doe (Google or Apple), go through the same screens, and
   capture with `xcrun simctl io booted screenshot <name>.png` into
   `store_screenshots/raw/ios_phone/` and `store_screenshots/raw/ipad/`.
   Google sign-in on iOS uses the reversed client ID in `Info.plist`; no
   fingerprint step.
4. Extend `build.py`: add the devices to `RAW_SIZE` and `CROP`, and add sets
   for `app_store_screenshots` (canvas 1284 × 2778) and
   `ipad_store_screenshots` (2064 × 2752). The page is laid out on a fixed
   1080 × 1920 canvas today; for iOS, make the canvas size per set instead of
   scaling, since neither iOS size is 9:16. Use `CHROME` at
   `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.
5. The App Store set has room for 10 slides; the Android eight plus Trips and
   Statistics are the natural extras. Keep "Google Play" and "Android" out of
   every App Store image — it's a rejection risk (see
   `docs/app_store_listing.md`).
