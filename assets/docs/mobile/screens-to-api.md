# Mobile app screens → API

Written 2026-10-12 after the server search, the price preview, the region cover and the review visit fields were built; updated 2026-10-14 for the hosted API. The seed for the Postman collection (`postman/`). Source: the Figma "High Fidelity Version 3" screens (ask Kimleng for them), checked against the API on branch `kimleng`. Base URL `https://api.travel.ams.com.kh/api/v1`; the paths below are relative to it. "Public" means no token. Everything else needs a Keycloak access token from the `amstravel` realm (public client `amstravel-mobile`, PKCE; see `README.md`). The Menu screen is out of scope by Kimleng's decision.

Paged answers look like `{"content": [...], "page": {"size": 20, "number": 0, "totalElements": 61, "totalPages": 4}}`.

Legend: ✅ exists and fits · ⚠️ exists with a gap · ❌ nothing behind it

## Sign-in (Keycloak, not this API)

| Screen | Behind it | State |
| --- | --- | --- |
| Register, Log in, Forgot password | Keycloak `amstravel` realm: registration on, login with email on, reset on | ✅ through Keycloak's pages |
| Continue with Google | a Keycloak identity provider, once a Google OAuth client exists | ⚠️ not configured yet |
| Continue with Apple | dropped | out of scope |
| Verify OTP (6-digit email code) | Keycloak's registration flow ends with the email-code step (`src/main/keycloak`): the code is emailed to the address typed, entered on Keycloak's page; resend after 60 s, 5 tries, valid 5 minutes | ✅ through Keycloak's pages |
| Explore as Guest | every read marked public below | ✅ |
| After sign-in | `GET /users/me`, `GET /preferences/me` | ✅ |

## What changed on 2026-10-16

Three small additions, ported from the developer's branch: `GET /search?type=DESTINATION&near=` takes `radiusKm`
(0.1 to 50; 25 when left out) and every attraction card found that way carries `distanceMeters`; an interest has
a picture (`coverUrl`, folder `interest`; `iconKey` stays until the app draws pictures); a tourism region has a
map picture (`mapUrl`: one image in the Map panel of its page, where the interactive map of its places used to be)
and an `amsRecommended` flag for the Recommended by AMS Travel badge. A destination's `theme` may be the code of
any tourism region, not only the nine first ones. History & Heritage stays out: there is no `history` schema and
no historical-coverage endpoint.

## What changed on 2026-10-14 (the answers to API-REQUESTS.md)

Every entry of `API-REQUESTS.md` has its Status line; the rows below are updated to match. In short: several
regions or provinces per search (`regionIds`, `provinceIds`), the Traveler seal filter (`travelerRecommended=true`),
cards around a destination (`near=`), the Provinces page in one answer (`GET /search/by-province`), the Popular
row filled and typed (`type=`, `items[].reason`), provinces with a picture, a centre, bounds and counts, regions
with a centre and bounds, regions and provinces as favourites, corridor cards with `stopNames` and
`encodedPolyline`, corridor galleries, food cards with `openNow`/`todayHours`, a documented hours format, a star
filter on both review lists, home province and `profileCompletion`, `distanceUnit`, `percentile`, `shareUrl`.
Parked by Kimleng: riel prices, saved folders, helpful votes, reporting a review (Khmer content was built on 2026-10-21, see R-004); declined: a
first/last name split (one Full name stays).

## The one card every list is made of

`GET /search`, `GET /search/cards` and the filtered lists all return the same **card**: `type`, `id`, `name`, `slug`, `shortDescription`, `coverUrl`, `provinceId`, `provinceName`, `latitude`, `longitude`, `categoryIds`, `categoryNames`, `interestIds`, `tourismRegionIds`, `averageRating`, `ratingCount`, `reviewCount`, `verified`, `basis`, `travelerRecommended`, `priceFrom`, `currency`, `durationDays`, `openNow`, `todayHours` (food: open at this moment in Cambodia, null when no hours are known; today's line), `stopNames`, `encodedPolyline` (corridors: the stops in travel order; the whole route, Google encoded, null until calculated), `distanceMeters` (attractions searched `near=` a destination: metres from it; null otherwise). A row in the app needs nothing else. Fields a kind does not have are null (a stay has no slug, a corridor no pin or province, only a stay or food a price, only a corridor a duration).

## Explore

| Element | Endpoint | State |
| --- | --- | --- |
| Chip row: Attraction Site, Stays, Food, Water, Activities, Corridors | `GET /interests` (public) grouped by `groupName`: the six groups are exactly these | ✅ |
| Explore by Tourism Region cards | `GET /regions?kind=TOURISM` (public) → `name`, `coverUrl`, `description`, `latitude`, `longitude` (an editor's centre when `centreSet`, else the middle of its places), `bounds`, `amsRecommended` (the Recommended by AMS Travel badge); the heart: `POST /favorites` `{targetType: REGION, targetId}` | ✅ |
| Explore by Provinces cards | `GET /provinces` (public) → `name`, `coverUrl`, `averageRating`, `reviewCount`, `placeCount`; the heart: `POST /favorites` `{targetType: PROVINCE, targetId}` | ✅ |
| "Recommend by Traveler" on a region card | nothing: the seal is per destination | design filler |
| Explore by Popular | `GET /popular?limit=10` (public; `type`, `regionIds`, `provinceIds`, `interestIds` optional) → `items[{type, id, browses, reason}]`, filled up to `limit` (MOST_BROWSED, then VERIFIED, TOP_RATED, CATALOGUE), then `GET /search/cards?type=&ids=` for the rows | ✅ |
| Recording a browse (feeds Popular) | `POST /popular/events` `{targetType: DESTINATION|STAY|FOOD|ACTIVITY|CORRIDOR, targetId, eventType, sessionId}` (public, counts when signed in; `destinationId` still accepted); or `PUT /badges/me/explorations/{destinationId}` when signed in (also the Browser badge) | ✅ |
| Location, notification bell | device location; `GET /notifications?unreadOnly=true&limit=1` | ✅ |

## Search

| Element | Endpoint | State |
| --- | --- | --- |
| Keyword search | `GET /search?q=angkor&page=0&size=20` (public): published places only, name order, size ≤ 100 | ✅ |
| Kind chips (All, Stays, Food, Activities, Corridors) | `GET /search?type=DESTINATION|STAY|FOOD|ACTIVITY|CORRIDOR` | ✅ |
| Filters: Tourism Regions, Provinces, Interests, Categories, Tags | `GET /search?regionIds=a,b&provinceIds=c,d&interestIds=&categoryIds=&tagIds=` (several of each; `regionId`/`provinceId` still take one; a region id may be a zone or a tourism region); the chips come from `GET /regions?kind=TOURISM`, `GET /provinces`, `GET /interests`, `GET /categories`, `GET /tags` (all public) | ✅ |
| Only the Traveler seal holders | `GET /search?travelerRecommended=true` (destinations; the bar is 10,000 ratings at 4.5, so empty until a place reaches it: hide the panel while `content` is empty) | ✅ |
| Typing suggestions ("Angkor Wat", "Battambang") | `GET /search/suggest?q=ang&limit=8` (public) → `kind` (DESTINATION, STAY, FOOD, ACTIVITY, CORRIDOR, PROVINCE, REGION), `id`, `name`, `slug`; names starting with the text first | ✅ |
| Recent keywords | on the device | ✅ |
| Explore by Nearby | `GET /destinations/nearby?latitude=&longitude=&radiusKm=25&limit=20` (public) → ids, then `GET /search/cards?ids=` | ✅ |
| Around a destination, as cards | `GET /search?type=STAY|FOOD|ACTIVITY|DESTINATION|CORRIDOR&near={destinationId}` → `{content, page}` nearest first (stays, food and activities within the Nearby radius, attractions within `radiusKm` (0.1 to 50; 25 when left out) each with `distanceMeters`, corridors stopping there) | ✅ |
| Recommend Corridors | `GET /search?type=CORRIDOR` (public) | ✅ (the seal and review count on a corridor are filler until corridors have reviews) |

## Tourism Regions

| Element | Endpoint | State |
| --- | --- | --- |
| Region list with three places each | `GET /regions?kind=TOURISM` + `GET /search?regionId=&size=3` per region | ✅ |
| Region detail: banner, name, overview, map picture | `GET /regions/{id}` → `coverUrl`, `name`, `description` (HTML), `mapUrl` (the Map panel: one picture of the region's map, where the interactive map was; null until staff upload one), `amsRecommended` | ✅ |
| Historical Map | the cards' `latitude`/`longitude` from `GET /search?regionId=&size=100`; the region's own `bounds` to frame it | ✅ |
| Categories and Tags chips | `GET /regions/{id}` → `categoryIds`, `tagIds` resolved against `GET /categories`, `GET /tags` | ✅ flat lists, no values |
| Destination list with category line and seal | `GET /search?regionId=` → `categoryNames`, `verified`, `travelerRecommended` on every card | ✅ |

## Destination detail (attraction)

| Element | Endpoint | State |
| --- | --- | --- |
| Cover and gallery | `GET /destinations/{id}` → `coverUrl`; `GET /media?ownerType=DESTINATION&ownerId=` (public) | ✅ |
| Name, categories, slogan quote and its author, description, address, map pin | `GET /destinations/{id}` → `name`, `categoryIds`, `slogan`, `sloganBy`, `description`, `address`, `latitude`, `longitude` | ✅ |
| Rating, review count, seal | `GET /search/cards?ids={id}` gives all three in one call; or `GET /ratings/summary?targetType=DESTINATION&targetIds=`, `GET /reviews/summary?...`, `GET /destination-verifications/status?destinationId=` | ✅ |
| What Travelers Say, Show all reviews | `GET /reviews?targetType=DESTINATION&targetId=&page=&size=` (public) → author, rating, title, content, `visitType`, `visitedOn`, photos | ✅ |
| Recommend Nearby | `GET /destinations/nearby?latitude=&longitude=` with the place's own coordinates, then `GET /search/cards?ids=` | ✅ |
| Heart (save), Share | `POST /favorites` `{targetType: DESTINATION, targetId}`, `DELETE /favorites/DESTINATION/{id}` (signed in); share = app link | ✅ |
| How to get there (route, time, distance) | device maps SDK from the user's location to the pin | ✅ client side |
| Highlights / About sheet | the same `description` | design filler |
| Write a Review | `POST /reviews` `{targetType, targetId, rating 1–5, title ≤200, content ≤5000, visitType, visitedOn "YYYY-MM", photoKeys[]}`; photos first via `POST /media/files` (type `review`) | ✅ |
| Check in ("I'm here", the Adventure badge) | since 2026-10-20 the QR code posted on site AND the device position, both: scan the code, then `POST /stamps` `{code, latitude, longitude}` (`code` = the scanned text, a link whose last part is the code; signed in) → `outcome` COLLECTED / ALREADY_COLLECTED (this season) / TOO_FAR / INVALID_CODE, `targetType`, `destinationId`, `distanceMeters`, `radiusMeters`, `badgesEarned`. Once per place per season. Stays and food places are checked in the same way, with their own codes | ✅ needs a screen in the design |

## Popular page

| Element | Endpoint | State |
| --- | --- | --- |
| Long list filtered by province chips and kind chips | `GET /popular?type=DESTINATION|STAY|FOOD|ACTIVITY|CORRIDOR&provinceIds=a,b&interestIds=&limit=50` → `items[]`, then `GET /search/cards?type=&ids=`; the kind chips are `type`, the interest chips `interestIds` | ✅ |
| Results state (typing) | `GET /search/suggest` and `GET /search?q=` | ✅ |

## Interests, Stays and Food

| Element | Endpoint | State |
| --- | --- | --- |
| Interest chips and grid | `GET /interests` (public) → `coverUrl` (its picture, null until staff choose one; `iconKey` stays for now); `GET /search?interestIds=` | ✅ |
| "Recommend" panel (Traveler seal holders of the interest) | `GET /search?interestIds=&travelerRecommended=true&size=5`; hidden while empty | ✅ |
| Stay detail: cover, gallery, name, star rating, slogan, description, policies, check-in/out, phone, website, amenities | `GET /stays/{id}` (public) → `starRating`, `slogan`, `description`, `policies`, `checkInFrom`, `checkOutUntil`, `phone`, `website`, `amenities` (slugs → `GET /amenities` for label, icon, group), `weekendNights`; gallery `GET /media?ownerType=STAY&ownerId=` | ✅ |
| "Open 24h" on a stay | nothing: stays have check-in hours, not opening hours | design filler |
| Stays near a destination | `GET /search?type=STAY&near={destinationId}` (public) → cards, nearest first; `GET /stays?near=` still answers the full details | ✅ |
| Rooms list and Room Details (capacity, size, breakfast, amenities by group, photos) | `GET /stay-rooms?stayId=` (public) → `maxAdults`, `maxChildren`, `sizeSqm`, `breakfastIncluded`, `amenities`, `photoUrls`, `description`, `pricePerNight`, `weekendPrice`; groups from `GET /amenities` | ✅ |
| Dates, rooms, adults, children picker and the price | **Price preview, no booking.** `GET /stay-rooms/quote?stayId=&checkIn=2026-10-16&checkOut=2026-10-18&rooms=1&adults=2&children=0` (public; dates default to tonight) → `nights`, `currency`, `fromTotal`, and per room `total`, `weekendNightCount`, `perNight[]`, `fitsGuests`, `enoughRooms`, `meetsMinNights`, `bookable`. The app prints "US$300 total for 2 nights" and never a nightly price. One room: `GET /stay-rooms/{id}/quote?...` | ✅ |
| Stay rating and "What Travelers Say" | `GET /ratings/summary?targetType=STAY`, `GET /reviews?targetType=STAY&targetId=` | ✅ |
| Food detail: cover, name, price range, hours (open/closed), cuisines, meals served, phone, website, slogan, description, map, nearby | `GET /foods/{id}` (public) → `priceRange`, `openingHours` (keys `mon`…`sun`; `07:00-22:00`, `closed` or no key for a shut day; a close before its open runs past midnight; `24:00` is midnight), `openNow` (boolean, null when no hours), `todayHours`, `cuisines`, `mealsServed`, `phone`, `website`, `slogan`, `description`, `latitude`, `longitude`, `averageRating`, `reviewCount` | ✅ |
| Food near a destination | `GET /search?type=FOOD&near={destinationId}` (public) → cards, nearest first; `GET /foods?near=` still answers the full details | ✅ |
| Menu | out of scope | skip |

## Activities & Experiences (since 2026-10-21)

The fourth kind of destination: something a traveller does rather than visits (a dive trip, a kayak tour, a bird safari, a trek, a cruise). It is built like an attraction and run by someone you can contact.

| Element | Endpoint | State |
| --- | --- | --- |
| Activities list and the chips Diving, Kayak, Bird Sanctuary, Wildlife, Hiking/Trekking, Fishing, Camping, Viewpoint, Cruise, Shopping | `GET /search?type=ACTIVITY` (public; `q`, `regionIds`, `provinceIds`, `categoryIds`, `tagIds`, `interestIds`, `travelerRecommended`, `lang=km` as for any kind) → the same card, `type` ACTIVITY, classed by its `interestIds` alone like a stay (`categoryIds` and `tourismRegionIds` are empty; a region filter reaches it through its province); the ten chips are the interests of the "Activities & Experiences" group (`GET /interests`), so a chip is `interestIds=`. `GET /activities/{id}` answers `type` (DIVING, KAYAK, BIRD_SANCTUARY, WILDLIFE, HIKING_TREKKING, FISHING, CAMPING, VIEWPOINT, CRUISE, SHOPPING, OTHER) | ✅ |
| Activity detail: cover, gallery, name, type, slogan, description, address, map, contact | `GET /activities/{id}` (public) → `type`, `slogan`, `sloganBy`, `description`, `address`, `latitude`, `longitude`, `phone`, `contactEmail`, `website`, `telegram`, `whatsapp`, `facebookUrl`, `provinceId`, `interestIds`, `viewCount`, the Khmer twins (`nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm`); gallery `GET /media?ownerType=ACTIVITY&ownerId=` | ✅ |
| Activities near a destination | `GET /search?type=ACTIVITY&near={destinationId}` (public) → cards, nearest first; `GET /activities?near=` still answers the full details | ✅ |
| Rating, reviews, the heart, check-in, the Browser badge | `GET /ratings/summary?targetType=ACTIVITY`, `GET /reviews?targetType=ACTIVITY&targetId=`, `POST /reviews` `{targetType: ACTIVITY, …}`, `POST /favorites` `{targetType: ACTIVITY, targetId}`, the QR code posted on site (`POST /stamps`), `PUT /badges/me/explorations/{id}`, `POST /popular/events` `{targetType: ACTIVITY, …}` | ✅ |
| Price, duration, opening hours | not yet: an activity has no price, duration or hours for now | design filler |

## Provinces

| Element | Endpoint | State |
| --- | --- | --- |
| Province list, "Show all 25 provinces" | `GET /provinces` (public), 25 rows → `coverUrl`, `latitude`, `longitude`, `bounds`, `placeCount`, `averageRating`, `reviewCount` | ✅ |
| Provinces page: one row per province with its first places for the chosen chips | `GET /search/by-province?interestIds=&type=&perProvince=8` → `[{provinceId, provinceName, totalElements, content}]`, provinces with nothing left out | ✅ |
| Places in a province, kind and interest chips | `GET /search?provinceId=&interestIds=`; the Tourism Corridors chip: `GET /search?type=CORRIDOR&provinceId=` (corridors with a stop there) | ✅ |

## Map

| Element | Endpoint | State |
| --- | --- | --- |
| Pins around the user, Explore by Nearby | `GET /destinations/nearby` then `GET /search/cards?ids=` | ✅ |
| Filter chips (regions, provinces, interests, corridors) | `GET /search?...&size=100` and read the cards' pins | ✅ |
| A marker per province and per region | `GET /provinces` and `GET /regions?kind=TOURISM` → `latitude`, `longitude` (the centre), `bounds` to frame it | ✅ |
| Corridor lines on the map | every line at once: `GET /search?type=CORRIDOR` → each card's `encodedPolyline` (Google encoded); one corridor: `GET /corridors/{id}/itinerary` → stops with `routePolyline` | ✅ |
| Route to a place, Start Route | device maps SDK | ✅ client side |

## Corridors

| Element | Endpoint | State |
| --- | --- | --- |
| List: name, duration, cover, stops | `GET /search?type=CORRIDOR` → `name`, `durationDays`, `coverUrl`, `stopNames`, ratings | ✅ |
| "What you expect" chips | `interestIds` → `GET /interests` | ✅ |
| About, Route Overview (stops with description), Corridors Map | `GET /corridors/{id}/itinerary` → days, stops (sequence, destination, title, description, arrival, departure, distance, travel minutes, polyline) | ✅ |
| Gallery | `GET /media?ownerType=CORRIDOR&ownerId=` (since 2026-10-14; photos attached in the CMS) | ✅ |
| Rating, reviews and the Traveler seal on a corridor | `GET /reviews?targetType=CORRIDOR&targetId=`, `POST /reviews` with `targetType: CORRIDOR`; the seal stays a destination thing | ✅ reviews; seal is filler |
| Heart on a corridor | `POST /favorites` `{targetType: CORRIDOR, targetId}` | ✅ |

## Saves

| Element | Endpoint | State |
| --- | --- | --- |
| All saved places | `GET /favorites` (signed in) → `targetType`, `targetId`, then `GET /search/cards?type=&ids=` per type for the rows | ✅ |
| Tabs Regions / Provinces / Interests | saved regions and provinces: `GET /favorites` rows with `targetType` REGION / PROVINCE, resolved against `GET /regions` and `GET /provinces`; places grouped by `tourismRegionIds`, `provinceId`, `interestIds` | ✅ |
| Folders | on the device (parked 2026-10-14) | ❌ parked |

## Notifications

| Element | Endpoint | State |
| --- | --- | --- |
| List, All / Unread, mark read | `GET /notifications?unreadOnly=&limit=`, `PUT /notifications/{id}/read`, `PUT /notifications/read-all`, `DELETE /notifications/{id}` (signed in) | ✅ |
| "New places added in Siem Reap", "Complete your profile", "New information updated" | nothing produces them yet: the only types are PUBLISH_APPROVED / REJECTED / CHANGES_REQUESTED, which are staff events | ❌ parked |
| Push delivery | no FCM / APNs integration; `notificationPush` is only stored | ❌ parked |

## Profile and Account

| Element | Endpoint | State |
| --- | --- | --- |
| Name, photo, phone, joined date, province, completion | `GET /users/me` → `fullName`, `avatarUrl`, `phone`, `createdAt`, `homeProvinceId`, `homeProvinceName`, `profileCompletion` (0–100: name, email, phone, picture, home province, 20 each); `PUT /users/me` `{fullName, phone, avatarKey, homeProvinceId}` (the whole profile each time: a field left out is cleared); photo via `POST /media/files` (type `avatar`) | ✅ |
| First name / Last name split | one "Full name" input stays (declined 2026-10-14: Khmer and multi-word names) | ✅ decided |
| Email and password change | Keycloak account, not this API | ⚠️ decide the flow |
| Review (4) tile | `GET /reviews/me` (signed in) | ✅ |
| Check-ins and points | `GET /stamps/me` (collected stamps, each with `targetType` DESTINATION / STAY / FOOD), `GET /points/me` (signed in; points are a season total only since 2026-10-20, no badge rests on them) | ✅ need a place in the Profile design |
| Sign out | token revocation on the device | ✅ |

## Badges

| Element | Endpoint | State |
| --- | --- | --- |
| Badge overview, current status, progress bar, "this season" | `GET /badges/me/progress?seasonId=` (signed in) → tracks, badges, earned; `GET /seasons/current` (public) | ✅ |
| Badge categories Browser / Adventure / Reviewer | `GET /badges` (public): three ladders, `type` BROWSES / REVIEWS / STAMPS, each SILVER / GOLDEN / PLATINUM (the POINTS ladder was retired on 2026-10-20). Browser: a destination opened counts once per place per day; Reviewer: one review per place (a second attempt is refused); Adventure: one stamp per place per season. Attractions, stays and food places all count as destinations | ⚠️ design says Gold / Silver / Bronze; the API has Silver, Golden, Platinum |
| Tier thresholds ("300 browses required") | each badge's `threshold` | ✅ |
| Adventure badge | counts QR check-ins (scan + position): `POST /stamps`, `GET /stamps/me` | ✅ needs the check-in screen |
| Achievement, Share to Facebook, View badge history | `GET /badges/me/earned` → each row's `shareUrl` (`https://api.travel.ams.com.kh/api/v1/badges/shared/{userBadgeId}/page`, a public page with Open Graph tags: give it to the share sheet); `GET /badges/shared/{userBadgeId}` (public page data); `GET /seasons/me/history` | ✅ |
| "Top 5% of active members" | `GET /badges/me/progress` → `percentile` (5 means the top 5%; null with no activity this season) | ✅ |

## Reviews (mine)

| Element | Endpoint | State |
| --- | --- | --- |
| Reviews written, average rating, list with sort and the star filter | `GET /reviews/me?page=&size=&sort=&rating=5` (signed in; `rating` repeatable or `4,5`); average from the rows | ✅ |
| All reviews of a place, "All (500)" menu with 5 ★ … 1 ★ | `GET /reviews?targetType=&targetId=&rating=5`; the counts per star from `GET /ratings/summary` → `stars` | ✅ |
| Helpful votes, Report review | parked 2026-10-14; leave the button and the menu out | ❌ parked |
| Review detail: stars, date, kind of visit, visit month, title, body, photos | `GET /reviews/{id}` → `rating`, `createdAt`, `visitType`, `visitedOn`, `title`, `content`, `photos` | ✅ |
| Edit, delete | `PUT /reviews/{id}`, `DELETE /reviews/{id}` | ✅ |
| Search for a place to review | `GET /search/suggest?q=` | ✅ |

## Preferences

| Element | Endpoint | State |
| --- | --- | --- |
| Language (EN / KH), Currency (KHR / USD), Notification on/off | `GET /preferences/me`, `PUT /preferences/me` `{preferredLanguage, preferredCurrency, preferredRegionId, notificationEmail, notificationPush, theme, distanceUnit}`; riel prices are parked (2026-10-14): prices come in the API's currency. Khmer content since 2026-10-21: with the language on KH ask `?lang=km` on `/search`, `/search/by-province`, `/search/suggest` and `/search/cards` (cards carry the Khmer where written and list what is still English in `untranslated`), and read `nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm` on a listing, `nameKm` (+ `descriptionKm`) on provinces, regions, categories, tags and interests; fall back to the English field when the Khmer one is null | ✅ |
| Units (km / mi) | `distanceUnit` `KM` or `MI` on the same calls | ✅ |

## Help & Support, Terms & Conditions

Static text and links. No endpoint; ship them in the app, or add a small settings read later if they must change without a release.

## In the API, absent from the design (decided 2026-10-12)

- Check-ins (`POST /stamps`) and points (`GET /points/me`) are IN: the designer adds a check-in action on the destination, stay and food pages (a scan screen) and a stamps and points area in Profile.
- `GET /recommendations/for-you` (personal recommendations): no screen; left as is.
- Seasons (`GET /seasons`, `/current`, `/me/progress`, `/me/history`): referenced by the badge screen only.
- Food: 40+ fields served, about 10 read by the design. Stay: 20 policy fields served, the design shows one policies box plus check-in/out. Room: 50 fields served, about 10 read. The Postman collection documents what the app reads.
- Preferences `theme`, `preferredRegionId`.

## Content on the server today (staging seed, last reseeded 2026-10-21)

The staging server is seeded with a full, lively catalogue, so every screen has something to show: 59 published
attractions with long descriptions, slogans and galleries of 3 to 5 photos; 5 activities with contact details;
5 corridors with itineraries and galleries; 25 provinces with a cover, a centre and counts; 14 tourism regions
and zones with covers; 33 interests in 6 groups, 65 categories, 53 tags, 72 amenities; 20 sample stays with 56
rooms and price previews; 25 sample food places with opening hours; 24 sample travellers with published reviews
and ratings over the last five months, browses over the last month (so Popular is real), and Verified decisions;
badge definitions and seasons. Since 2026-10-21 every seeded place, province, region, category, tag and interest
carries Khmer text beside the English. The stays, food places, activities, travellers and reviews are fictional
staging content; photos come from Wikimedia Commons, credited in each gallery caption. A reset reseeds all of
it: nothing you create on the staging server is kept across one, and every id changes — the last reset ran on
2026-10-21, so ids cached before that date are stale.

## What changed on 2026-10-21

- **Activities & Experiences, a fourth kind of destination.** `type=ACTIVITY` on `GET /search`, `/search/by-province`, `/search/cards` and `GET /popular`; `kind` ACTIVITY in `/search/suggest`; `GET /activities` and `GET /activities/{id}`; `targetType` ACTIVITY on reviews, ratings, favorites, browse events, stamps and `GET /destination-verifications/status`; `ownerType` ACTIVITY on `GET /media`. The card is the same; an activity is classed by its interests alone, like a stay. See the Activities & Experiences section. The staging seed ships five.
- **Khmer content (R-004, declined before, now BUILT).** With the app's language on Khmer, ask `?lang=km` on `GET /search`, `/search/by-province`, `/search/suggest` and `/search/cards`: cards and suggestions come in Khmer where written, and `untranslated` names the fields still in English. Detail answers carry the Khmer beside the English: `nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm` on attractions, stays, food places and activities; `nameKm` (and `descriptionKm` on regions and interests) on provinces, regions, categories, tags and interests. Fall back to the English field when the Khmer one is null — Khmer is optional on the CMS side. Any search also matches Khmer names and addresses, whatever the `lang`.
- **The staging catalogue was reseeded on 2026-10-21** (for the activities and the Khmer text): every id changed again — clear caches and saved test data first.

## What changed on 2026-10-20

- **Check-in by QR code.** `POST /stamps` now takes `{code, latitude, longitude}`; `destinationId` is gone. The code is what the QR posted on site encodes: a link like `https://api.travel.ams.com.kh/api/v1/stamps/scan/ABCD-EFGH-JKLM`; send the whole scanned text or just its last part. Both the code and the position are checked; a new `outcome` INVALID_CODE says the code is unknown, withdrawn or retired. One stamp per place per season (was per day). A stamp carries `targetType` (DESTINATION, STAY, FOOD) and `source` QR.
- **The scanned code names the place, not the screen.** A place may post several codes at once (the gate, a brochure), and any scan button may scan any place's code. Show the check-in result for the place the RESPONSE names (`targetType`, `destinationId`), never for the screen the scanner was opened from: scanning place A's code from place B's page checks in at A.
- **Every kind is a destination.** Stays and food places (and, since 2026-10-21, activities) are stamped (their own codes), browsed for the Browser badge (`PUT /badges/me/explorations/{id}` takes any kind's id) and viewed (`viewCount` on `GET /stays/{id}`, `GET /foods/{id}` and `GET /activities/{id}`) exactly like attractions.
- **The Explorer (POINTS) ladder is retired.** `GET /badges` and `GET /badges/me/progress` answer three ladders. Points stay as season totals (`GET /points/me`, `GET /seasons/me/progress`).
- **Destination Detail in the CMS** reads one place's standing by id: `GET /admin/destination-stats/{id}` (staff only; not for the app).
- **Verified for every kind.** `verified`, `basis` and `travelerRecommended` on stay and food cards are real now (they were always false before): a stay or a food place is verified by a desk like an attraction, and its reviews earn the Traveler seal. `GET /destination-verifications/status?destinationIds=` takes any kind's id and answers `targetType`; a `travelerRecommended=true` search keeps sealed stays and food places too.
