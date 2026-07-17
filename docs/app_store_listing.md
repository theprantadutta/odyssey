# App Store Connect listing copy

Everything here is written to Apple's field limits and checked against them. The
counts in brackets are exact — App Store Connect rejects anything longer, and
"Google Play" or "Android" anywhere in the metadata is a rejection risk.

Promotional Text and Keywords can be changed any time without shipping a build.
The Description and Subtitle need an app update.

---

## Subtitle (max 30)

```
Travel journal & trip planner
```
29/30. Indexed for search, so it is spent on searchable words rather than
atmosphere — the Promotional Text does the atmosphere.

Alternatives, if the tone matters more than the keywords:

- `Your trips, beautifully kept` (28)
- `Trip planner & photo journal` (28)

---

## Promotional Text (max 170)

```
Every trip, beautifully kept. Plan days, map your photos, split budgets across currencies, and tick off the packing list — all in one journal that works offline.
```
161/170. Sits above the description and can be swapped without a release, so it
is the place for a hook or a seasonal angle.

Alternative, if one idea beats four:

```
Your trips deserve better than a camera roll. Map every photo where you took it, plan the days, track the spend, and keep tickets and passports close at hand.
```
158/170.

---

## Keywords (max 100)

```
itinerary,packing,budget,expense,currency,map,photos,memories,vacation,holiday,diary,adventure
```
94/100.

Two rules this obeys:

- **No spaces after the commas.** Spaces count against the 100.
- **No "travel", "journal", "trip" or "planner".** They are already in the app
  name and subtitle, which Apple indexes, so repeating them buys nothing.

If the subtitle changes to one without "travel"/"planner", use this instead (92):

```
travel,planner,itinerary,packing,budget,expense,currency,map,memories,vacation,holiday,diary
```

---

## Description (max 4000)

2053/4000.

```
Odyssey is a travel journal for people who want more than a camera roll.

Plan the trip, live it, and keep it — the itinerary, the receipts, the boarding pass, and every photo pinned to the spot where you took it. All in one place, all yours.

PLAN THE DAYS
Build an itinerary that actually helps. Add activities with times and places, sort them by day, and see the whole trip laid out — from the museum at ten to the restaurant you booked for eight.

MAP YOUR MEMORIES
Photos remember where they were taken. Odyssey puts them on the map, so a trip becomes something you can wander back through instead of scroll past.

KNOW WHAT YOU SPENT
Track expenses in the currency you paid in and see the total in the one you think in. Set a budget, watch it as you go, and find out where the money actually went — food, transport, that one unforgettable dinner.

PACK WITHOUT THE PANIC
Reusable packing lists organised by category, with quantities and notes. Tick things off as they go in the bag. Stop discovering at the airport that the charger is on the kitchen table.

KEEP THE PAPERWORK CLOSE
Tickets, reservations, insurance, passport scans. Store the documents that matter where you can find them, not buried three folders deep in your email.

EARN YOUR STRIPES
Badges for the milestones — first trip, fifty memories, a month on the road. A small nudge to keep the journal going.

SEE THE BIGGER PICTURE
Days travelled, trips completed, where your time and money go. Your travel life, in numbers.

WORKS WHERE YOU ARE
Your trips live on your device, so you can plan on a plane, add a memory in a dead zone, and check the packing list on a train through nowhere. Everything syncs when you're back on a signal.

PRIVATE BY DEFAULT
Your journal is yours. Share a trip when you want to, with the people you choose.

ODYSSEY PREMIUM
Upgrade for more storage, unlimited trips, and an ad-free experience. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in your account settings after purchase.
```

### Why it says what it says

- Every claim is real: multi-currency conversion, photo-on-map, packing categories
  with quantities, documents, achievements, statistics, local-first storage, trip
  sharing. Reviewers do check.
- Storage is left as "more storage" rather than a number, so tuning
  `SubscriptionLimits` later doesn't make the listing a lie. (Today: 1 GB free,
  25 GB premium.)
- "Works where you are" is deliberately not "fully offline" — browsing and editing
  work offline, but sign-in and sample trips need the network.
- The premium paragraph carries the auto-renewal disclosure Guideline 3.1.2 wants.
- No "Google Play" and no "Android" anywhere.

---

## Content Rights

**"Yes, it contains, shows, or accesses third-party content, and I have the
necessary rights."**

Odyssey shows third-party content in three places:

- **OpenStreetMap tiles** on the world map, the trip map, and the blurred premium
  teaser. The data is ODbL, so the credit is a licence requirement, not a courtesy -
  every map renders "© OpenStreetMap contributors" linking to the copyright page.
- **Unsplash photos** backing the demo trips' covers and memories. The Unsplash
  Licence permits free commercial use.
- **AdMob creative** served to free users, under the AdMob terms.

### Known risk: OSM tile hosting

The app fetches tiles straight from `tile.openstreetmap.org`. OSM's Tile Usage Policy
discourages exactly this for commercial apps, and they block heavy users. Not an App
Store problem, and fine at the current install base, but the maps will start failing
at some point. The fix is a `urlTemplate` and an API key pointed at a real tile
provider (MapTiler, Stadia, Thunderforest, Mapbox all have free tiers), plus whatever
attribution that provider requires on top of OSM's.

---

## App Privacy (the nutrition labels)

First question: **"Do you or your third-party partners collect data from this app?"**
→ **Yes.**

Declare these twelve. "Linked" means tied to identity; Analytics is linked because
`setUserId` is called with the backend user GUID, which maps to an email in Postgres.

| Data type | Purposes | Linked | Tracking |
|---|---|---|---|
| Contact Info → Email Address | App Functionality | Yes | No |
| Contact Info → Name | App Functionality | Yes | No |
| User Content → Photos or Videos | App Functionality | Yes | No |
| User Content → Other User Content (trips, expenses, notes, documents) | App Functionality | Yes | No |
| Identifiers → User ID | App Functionality, Analytics | Yes | No |
| Identifiers → Device ID (IDFA, AdMob) | Third-Party Advertising | No | **Yes** |
| Location → Precise Location | App Functionality | Yes | No |
| Location → Coarse Location (AdMob, IP-derived) | Third-Party Advertising | No | **Yes** |
| Purchases → Purchase History | App Functionality, Analytics | Yes | No |
| Usage Data → Product Interaction | Analytics, Third-Party Advertising | Yes | **Yes** |
| Usage Data → Advertising Data | Third-Party Advertising | Yes | **Yes** |
| Diagnostics → Crash Data | App Functionality | **No** | No |

### Why each is what it is

- **Precise, not Coarse, and Linked.** `LocationService` uses
  `LocationAccuracy.high` and the picker writes 6 decimal places (~0.1 m). It is
  optional and user-initiated, with no background collection - but it is uploaded and
  persisted as `Memory.Latitude/Longitude` and `Activity.Latitude/Longitude`, which
  hang off a Trip, which hangs off a User. Optional does not mean uncollected.
- **Crash Data is NOT linked.** Nothing calls `setUserIdentifier` or `setCustomKey`,
  so Crashlytics never learns the user id. If that changes, this row changes.
- **Tracking is Yes because ads are personalized.** No `AdRequest` sets
  `nonPersonalizedAds` and there is no `npa` extra anywhere, so personalization is on
  by default outside regulated regions, and ATT is requested with a usage string that
  says "personalized ads". That is tracking under Apple's definition.
- **Expenses are User Content, not Financial Info.** Apple's Financial Info means
  payment and account details - cards, banks, salary. These are trip budget records
  the user typed. No payment instrument is stored anywhere.
- **Amounts never reach analytics.** `expense_created` sends `category` + `currency`
  only.

### Judgement call worth knowing

**Product Interaction → Tracking: Yes** is the cautious answer. Firebase Analytics
data is not automatically fed to ad targeting, so a case exists for No. Yes is chosen
because AdMob and Firebase share a Google account context and the app already shows
the ATT prompt, so declaring it costs nothing and under-declaring tracking is a
rejection risk. Revisit if the ad setup changes.

### Known gap: video metadata

Photos go through `pickImage(maxWidth: 1920, imageQuality: 85)`, which re-encodes and
incidentally drops EXIF including GPS. **Videos go through `pickVideo` with no
re-encode, so embedded GPS survives the upload.** Nothing in either repo strips
metadata deliberately.

This does not change the label - Precise Location is declared as collected and linked
either way - but it means location reaches the server through a path no one designed,
for users who never tapped the location button. Worth stripping explicitly.
