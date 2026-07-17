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
