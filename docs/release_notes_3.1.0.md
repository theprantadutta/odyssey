# 3.1.0 (20) — release notes

Covers everything since 3.0.1 (19), released 22 Sep 2026.

## Google Play → Release notes (en-US, max 500)

Paste into the production release's "Release notes" box. Play shows it on
the store page as "What's new".

```
What's new in 3.1

• Try it without an account: start planning straight away. Your trips stay on this phone until you create a free account, then move to it.
• Your first trip in seconds: name it, pick the dates and you're in. Pick past dates to keep a trip you've taken as a journal.
• Offline fixes: reordering plans and packing items, and ticking a whole packing category, now sync reliably.
• The world map opens on your trips, not the ocean.
• Smaller download, plus fixes.
```
478/500.

In the Play Console box itself, wrap it in the language tag:
`<en-US>` … `</en-US>`.

## App Store → What's New (max 4000)

Same text. No "Android" or "Google Play" anywhere in it.

## Full changelog (website, GitHub release, support)

### New
- **Use Odyssey without an account.** "Continue without an account" on the
  sign-in and register screens. Everything a guest adds is kept on the phone
  only, with a clear warning first: it isn't backed up or synced, and is lost
  if the app is deleted or the phone changes. Create a free account or sign
  in at any time and everything moves to it. Settings shows the same reminder,
  which can be hidden for good.
- **"Where to next?" onboarding.** New accounts are asked for a destination
  and dates, and land straight inside their new trip. Past dates turn it into
  a journal of a trip already taken. Sample trips and an empty start are still
  offered.

### Improved
- **Offline sync for bulk edits.** Reordering activities, reordering packing
  items and ticking a whole packing category now go through the sync queue
  like every other edit, so changes made offline reach the server — and the
  other devices — once you're back online. Before, they could be lost.
- **Changes sync sooner after signing in.** Anything waiting is sent
  immediately, rather than on the next periodic sync.
- **Sample trips** can now be removed from Settings whenever an account has
  them, not only straight after adding them.
- **Smaller download** from resource shrinking in the Android build.

### Fixed
- The world map could open on an empty stretch of ocean on tall phones
  instead of framing your trips.

### Behind the scenes
- Screen analytics now record real screen names (Home, Trips, Trip detail,
  each form) and tab switches, replacing the generic "MainActivity" entries.
- Guest sessions never contact the server; account features (photos,
  documents, cover photos, sharing, templates, Pro) offer an account instead.
- iOS build moved from CocoaPods to Swift Package Manager.
- Gradle wrapper 9.8.2.

## Shipping together

- Play listing draft (new title "Odyssey Trip Planner & Journal", short and
  full description, phone + 7" + 10" tablet screenshots) is saved, unsent, in
  Play Console → Store listings → Default listing.
- Before uploading a build signed with a new key, register its SHA-1 in
  Firebase, or Google sign-in fails on it.
- App Store screenshots still to be redone on a Mac — see
  `docs/store_screenshots.md`.
