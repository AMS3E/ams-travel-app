# API requests from the mobile app

This file is the one channel through which the app asks the backend for a change. The app follows the
Figma screens and the API follows its data model, so in places they disagree: a field a screen needs that
no endpoint returns, a value in the wrong shape, a filter a list lacks, an action with no endpoint. The app
never patches around such a gap on the phone. The need is written here instead, Kimleng takes this file
to the backend, and the backend answers each entry in its **Status** line.

## How it works

1. Copy this file once into the root of the app repo and keep it there, under version control.
2. One entry per need, in the shape below, appended under **Entries**, newest last. Fill every line;
   "unknown" is an answer too. Never delete an answered entry.
3. On the screen, leave the element as a `TODO R-nnn` naming the entry, make it degrade gracefully
   (hide it, or show what the API has today), and carry on with the next screen.
4. Send the file to Kimleng as soon as an entry blocks a screen, otherwise at the end of the day. It comes
   back with the Status lines filled in; the app then uses what was built.

## What belongs here

- A field no endpoint returns.
- A value in the wrong shape for the screen: a month where the screen shows a full date, a code where it
  shows a label the app cannot derive, a number without its unit or currency, free text the screen must parse.
- A list that needs a filter, a sort, a count or a page size it does not have.
- An action with no endpoint.
- A screen that needs two or three calls where one answer would do.

## What does not belong here

- Anything `screens-to-api.md` already answers, including the card every list is made of.
- Labels and formatting the app can do itself (`GOLDEN` shown as "Gold", a date shown in Khmer).
- Styling, and the Menu screen, which is out of scope.
- Sign-in, sign-up, the email code and forgot-password: they are Keycloak's pages, not the API.

## Entry shape

```
### R-001 · <screen> · <element>
- **Screen:** the name as in the Figma, and the state (list, detail, empty, signed-in...)
- **Element:** what the user sees, in words
- **Endpoint:** the call the screen already makes, or "none"
- **Today:** what the API gives there: field and type, or nothing
- **Needed:** what the screen needs: field, type, an example value
- **Why:** one sentence, what breaks or looks wrong without it
- **Blocks the screen:** yes or no
- **Status:** requested YYYY-MM-DD
```

The backend writes only the Status line: `built YYYY-MM-DD, <endpoint or field>` or `declined: <reason>`.

## Example

### R-000 · Profile · name fields
- **Screen:** Profile, signed-in, editing
- **Element:** two inputs, First name and Last name
- **Endpoint:** `GET /users/me`, `PUT /users/me`
- **Today:** `fullName` (string), one value: "Dara Chan"
- **Needed:** `firstName` and `lastName` (string each), or the screen keeps one "Full name" input
- **Why:** splitting one string on a space gets Khmer and multi-word names wrong
- **Blocks the screen:** no, one input shows the full name meanwhile
- **Status:** example, not requested

## Entries


### R-001 · Explore · province pictures
- **Screen:** Explore (guest and signed-in), "Explore by Provinces" row; also the Provinces list
- **Element:** each province card is a photo with a heart, the name underneath
- **Endpoint:** `GET /provinces`
- **Today:** `id`, `regionId`, `name`, `slug`, `countryCode`, `isActive`; no picture
- **Needed:** `coverUrl` (string, a picture path like the other covers), e.g. `/api/v1/media/files/general/.../siem-reap.jpg`
- **Why:** every province card shows a blank placeholder
- **Blocks the screen:** no, the card shows a placeholder meanwhile
- **Status:** built 2026-10-14, `coverKey` and `coverUrl` on `GET /provinces`; the picture is chosen in the CMS province form (upload folder `province`)

### R-002 · Explore · province rating and place count
- **Screen:** Explore, "Explore by Provinces" row; Provinces list
- **Element:** under the province name, a star score with its review count, or "N places" when nothing is rated
- **Endpoint:** `GET /provinces`
- **Today:** nothing; getting it means one `GET /search?provinceId=` per province (25 calls) and averaging on the phone
- **Needed:** on each province `averageRating` (number or null), `reviewCount` (integer) and `placeCount` (integer, published places), e.g. `4.6`, `128`, `14`
- **Why:** the second line of the card is empty
- **Blocks the screen:** no, the card shows the name only
- **Status:** built 2026-10-14, `placeCount`, `averageRating` and `reviewCount` on each province: its published attractions, stays and food places together, the average weighted by each place's rating count; also `bounds` {north, south, east, west} around them

### R-003 · Explore · Popular when nothing has been browsed
- **Screen:** Explore, "Explore by Popular" row; the Popular page
- **Element:** a row of ten popular places
- **Endpoint:** `GET /popular?limit=10`
- **Today:** `{"days": 30, "regionId": null, "destinations": []}`: empty until travellers browse, and again for any region, province or interest with few browses
- **Needed:** when fewer than `limit` destinations have browses, fill the rest of `destinations` with a stable fallback (for example verified, then rated, then the CMS order), with `reason` telling which ones are filler
- **Why:** on a fresh server, after a wipe at launch and for any filtered view, the row is empty and the section hides
- **Blocks the screen:** no, the section hides when the list is empty
- **Status:** built 2026-10-14, `GET /popular` fills up to `limit`: browses first (`MOST_BROWSED`), then verified places (`VERIFIED`), then the best rated (`TOP_RATED`), then the catalogue A to Z (`CATALOGUE`); every row is in `items[]` with its `reason` and `browses` (0 for filler); `destinations[]` keeps the old shape

### R-004 · All screens · Khmer content
- **Screen:** every screen, with the language set to Khmer (EN / KH in Preferences)
- **Element:** names and descriptions of places, regions, provinces, interests and corridors
- **Endpoint:** all reads (`/search`, `/interests`, `/regions`, `/provinces`, the details)
- **Today:** English only; `Accept-Language: km` changes nothing
- **Needed:** the Khmer text, either through `Accept-Language` / a `lang=km` parameter answering in Khmer with English as fallback, or `nameKm` and `shortDescriptionKm` beside the English fields
- **Why:** the app's own text switches to Khmer but every name stays English
- **Blocks the screen:** no, the English names show meanwhile
- **Status:** built 2026-10-21 (unparked by Kimleng): `nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm` beside the English on attractions, stays and food places; `nameKm` (and `descriptionKm` on regions and interests) on provinces, regions, categories, tags and interests; `?lang=km` on `GET /search`, `/search/by-province`, `/search/suggest`, `/search/cards` answers the cards in Khmer where written, with `untranslated` naming the fields still in English. Khmer is optional on the CMS side for now, so fall back to the English field when the Khmer one is null

### R-005 · Saves · regions and provinces
- **Screen:** Explore (region cards, province cards), Tourism Region detail, Saved tabs Regions / Provinces; signed-in
- **Element:** the heart on a region or a province
- **Endpoint:** `POST /favorites`, `DELETE /favorites/{targetType}/{targetId}`, `GET /favorites`
- **Today:** `targetType` is DESTINATION, FOOD, STAY or CORRIDOR only
- **Needed:** `targetType` `REGION` and `PROVINCE` accepted by the three calls, e.g. `{"targetType": "REGION", "targetId": "56c67829-…"}`
- **Why:** the design puts a heart on every region and province card, and Saved has tabs for them
- **Blocks the screen:** no, those hearts are hidden meanwhile
- **Status:** built 2026-10-14, `targetType` `REGION` and `PROVINCE` on `POST /favorites`, `DELETE /favorites/{targetType}/{targetId}` and `GET /favorites`; a deleted region or province takes its hearts with it

### R-006 · All prices · prices in riel
- **Screen:** Preferences → Currency (KHR / USD), and every price: stay totals, food price, corridor budget
- **Element:** a price written in the currency the traveller chose
- **Endpoint:** `GET /stay-rooms/quote`, `GET /search` (`priceFrom`, `currency`), `GET /foods/{id}`, `GET /corridors/{id}`; `PUT /preferences/me` already stores `preferredCurrency`
- **Today:** each price comes in its own `currency` (USD in practice); nothing converts it, and the app may not keep its own exchange rate
- **Needed:** either prices answered in the traveller's `preferredCurrency` (or a `currency=KHR` parameter), or a `GET /exchange-rates` answer such as `{"base": "USD", "rates": {"KHR": 4100}, "date": "2026-10-14"}`
- **Why:** choosing KHR changes nothing on screen
- **Blocks the screen:** no, prices show in the currency the API sends
- **Status:** declined: parked by Kimleng on 2026-10-14, prices stay in the currency the API sends (USD); no rate is served yet

### R-007 · Corridor lists · stops on the card
- **Screen:** Tourism Corridors list, Interests (Tourism Corridors), Province places, Popular
- **Element:** under a corridor's name, the stops along it ("Angkor, Kampong Thom, Phnom Penh")
- **Endpoint:** `GET /search?type=CORRIDOR`
- **Today:** the card has `shortDescription` and `durationDays`; the stops need `GET /corridors/{id}/itinerary` per row
- **Needed:** on a CORRIDOR card `stopNames` (array of string, in order), e.g. `["Angkor Wat", "Sambor Prei Kuk", "Phnom Penh"]`
- **Why:** a row may not take a second call, so the stop line is missing
- **Blocks the screen:** no, the row shows the duration and description
- **Status:** built 2026-10-14, `stopNames` (array, travel order, a place named once) on every CORRIDOR card from `GET /search` and `GET /search/cards`

### R-008 · Saved · folders
- **Screen:** Saved, signed-in: the folders row ("Kep/Kampot", "Cuisines") and a folder's page
- **Element:** named folders of saved places; create, delete, add and remove a place
- **Endpoint:** none
- **Today:** nothing; favourites are one flat list
- **Needed:** `GET /favorite-folders` → `[{id, name, items: [{targetType, targetId}]}]`; `POST /favorite-folders {name}`, `DELETE /favorite-folders/{id}`, `PUT /favorite-folders/{id}/items/{targetType}/{targetId}`, `DELETE` of the same
- **Why:** folders cannot follow the traveller to another phone, and are lost on reinstall
- **Blocks the screen:** no, folders stay on the device meanwhile, holding favourites from the API
- **Status:** declined: parked by Kimleng on 2026-10-14, folders stay on the device

### R-009 · Place lists · open now
- **Screen:** every list of food places and attractions (place cards, Province, Interests, Search results)
- **Element:** "● Open" / "● Closed" and today's hours on a card
- **Endpoint:** `GET /search`, `GET /search/cards`
- **Today:** the card has no hours; only `GET /foods/{id}` has `openingHours`
- **Needed:** on a card `openNow` (boolean or null) and `todayHours` (string, e.g. "07:00–22:00"), computed in Cambodia time
- **Why:** the status line on the card is empty, and a row may not take a second call
- **Blocks the screen:** no, the status line is hidden
- **Status:** built 2026-10-14, `openNow` (boolean, null when no hours are known) and `todayHours` (`07:00-22:00` or `closed`) on every FOOD card, computed in Cambodia time; attractions have no opening hours in the model, so their cards carry null and no status line

### R-050 · Map · every corridor route at once
- **Screen:** Map, Corridors chip
- **Element:** all five corridor lines drawn together when the Corridors chip is on, before one is picked
- **Endpoint:** `GET /search?type=CORRIDOR`, `GET /corridors/{id}/itinerary`
- **Today:** the corridor card has no route; each line needs its own `GET /corridors/{id}/itinerary`, so the overview takes one call per corridor
- **Needed:** on a CORRIDOR card `encodedPolyline` (string, Google encoded, simplified for country zoom is fine), or `GET /corridors/routes` → `[{"corridorId": "…", "encodedPolyline": "…"}]` for the published corridors
- **Why:** the overview of every route on one map cannot be drawn without N calls
- **Blocks the screen:** no, the map draws a corridor's line once the traveller picks it
- **Status:** built 2026-10-14, `encodedPolyline` (Google encoded, the whole route, null until the route is calculated) on every CORRIDOR card from `GET /search?type=CORRIDOR`; no separate routes call

### R-051 · Map · a marker per province and per region
- **Screen:** Map, Provinces and Regions chips
- **Element:** one named marker per province (and per tourism region) on the country map, tapping it frames that area
- **Endpoint:** `GET /provinces`, `GET /regions?kind=TOURISM`
- **Today:** neither answer has a position; a province or region chip can only filter the cards (`GET /search?provinceId=` / `regionId=`)
- **Needed:** on each province and region `latitude` and `longitude` (its centre, number), and ideally `bounds` `{"north", "south", "east", "west"}` to frame it
- **Why:** the provinces and regions layers have no markers, only a chip row
- **Blocks the screen:** no, picking a chip pins the places inside it
- **Status:** built 2026-10-14, `latitude`, `longitude` and `bounds` {north, south, east, west} on each province (`GET /provinces`: the 25 capital towns are seeded, editable in the CMS; bounds around its published places, null with none) and on each region (`GET /regions`: the centre an editor set, else the middle of its places; bounds the same way)

### R-030 · Corridor detail · gallery
- **Screen:** Corridor detail (guest and signed-in), the photo carousel at the top with its "Gallery N" badge
- **Element:** the corridor's photos, swiped one after another
- **Endpoint:** `GET /media?ownerType=CORRIDOR&ownerId={id}` (as `screens-to-api.md` lists it)
- **Today:** `400` "Galleries are DESTINATION, STAY and FOOD; review photos come with their review"; only the corridor's `coverUrl`
- **Needed:** `ownerType=CORRIDOR` accepted, answering the same media list as for a destination (`id`, `mediaUrl`, `caption`, `sortOrder`, `isCover`), and the CMS able to attach photos to a corridor
- **Why:** the carousel has one picture, so there is nothing to swipe and the gallery badge is hidden
- **Blocks the screen:** no, the cover shows alone
- **Status:** built 2026-10-14, `GET /media?ownerType=CORRIDOR&ownerId={id}` answers the gallery like a destination's (`id`, `mediaUrl`, `caption`, `sortOrder`, `isCover`); the CMS corridor page attaches photos; a photo made cover becomes the corridor's `coverUrl`

### R-031 · Province places · corridors through a province
- **Screen:** Places in a province (and the Provinces list), the "Tourism Corridors" kind chip
- **Element:** the corridors that pass through the province
- **Endpoint:** `GET /search?type=CORRIDOR&provinceId={id}` (and `regionId=` for a tourism region)
- **Today:** `provinceId` and `regionId` are ignored for `type=CORRIDOR`: all 5 corridors come back for Siem Reap, and for any region
- **Needed:** with `type=CORRIDOR`, `provinceId` / `regionId` keep only the corridors with a stop in that province / region, e.g. `GET /search?type=CORRIDOR&provinceId=<Siem Reap>` → Khmer Civilization
- **Why:** the chip would list corridors that never touch the province
- **Blocks the screen:** no, the Tourism Corridors chip is hidden on the province pages
- **Status:** built 2026-10-14, with `type=CORRIDOR`, `provinceId`/`provinceIds` keep the corridors with a stop in that province and `regionId`/`regionIds` those with a stop in the zone or shelved in the tourism region; `GET /search?type=CORRIDOR&provinceId=<Siem Reap>` → Khmer Civilization

### R-032 · Provinces · places of each province in one answer
- **Screen:** Provinces list ("Explore by Provinces" → arrow), with the interest chips on top
- **Element:** one row per province with its first places for the chosen interest; provinces with nothing for it left out
- **Endpoint:** `GET /provinces`, then `GET /search?provinceId=&interestIds=&type=&size=8` once per province
- **Today:** up to 25 calls for the page, and again for every chip change; which provinces are empty for an interest is only known after calling each one
- **Needed:** one paged answer grouped by province, e.g. `GET /search/by-province?interestIds=a,b&type=DESTINATION&perProvince=8` → `[{"provinceId", "provinceName", "totalElements", "content": [card, …]}]`, provinces with no match left out
- **Why:** the page fires many calls while scrolling and rows appear and fold away one by one
- **Blocks the screen:** no, each row loads as it scrolls into view and an empty row folds away
- **Status:** built 2026-10-14, `GET /search/by-province?interestIds=a,b&type=DESTINATION&perProvince=8` (same filters as `GET /search`, `perProvince` 1–20, 8 unless asked) → `[{provinceId, provinceName, totalElements, content: [card, …]}]` A to Z by province, provinces with no match left out; a corridor is listed under each province it stops in

### R-033 · Interests · Recommend by Traveler panel
- **Screen:** Interests (Explore → arrow), under the grid of places
- **Element:** "Recommend": up to five places of the chosen interest that carry the Traveler seal
- **Endpoint:** `GET /search?interestIds=`
- **Today:** each card has `travelerRecommended` (boolean) but `/search` cannot filter on it; picking them out of one page on the phone would be filtering the catalogue on the phone, and misses the ones on later pages
- **Needed:** a `travelerRecommended=true` parameter on `GET /search` (and `/search/cards`), e.g. `GET /search?interestIds=a,b&travelerRecommended=true&size=5`
- **Why:** the panel cannot be filled
- **Blocks the screen:** no, the panel is hidden
- **Status:** built 2026-10-14, `travelerRecommended=true` on `GET /search` (destinations; stays, food and corridors carry no seal and answer empty); the bar stays 10,000 ratings at 4.5 (Kimleng, 2026-10-14), so the panel is empty until a place reaches it: hide it while `content` is empty

### R-020 · Search · several regions or provinces in the filters
- **Screen:** Search, Filters sheet (guest and signed-in), opened from Explore or from Search
- **Element:** the Tourism Regions and Provinces rows, where the design lets the traveller tick several (e.g. "Siem Reap" and "Battambang")
- **Endpoint:** `GET /search?regionId=&provinceId=`
- **Today:** `regionId` and `provinceId` take one uuid each; `categoryIds`, `tagIds` and `interestIds` already take lists
- **Needed:** `regionIds` and `provinceIds` (comma-separated uuid lists, any of them matches), e.g. `provinceIds=97fca9bd-…,8f0f4fed-…`; the same on `GET /popular` would let its province chips do the same
- **Why:** a second pick has to replace the first, so "temples in Siem Reap or Battambang" takes two searches
- **Blocks the screen:** no, the sheet allows one region and one province meanwhile
- **Status:** built 2026-10-14, `regionIds` and `provinceIds` (comma-separated, any matches) on `GET /search`, `GET /search/by-province` and `GET /popular`; `regionId`/`provinceId` still take one and add to the list; a region id may be a zone (matches through the province) or a tourism region (matches the shelf, and corridors through their stops)

### R-021 · Popular page · stays, food and corridors
- **Screen:** Popular page, the kind chips Stays, Food and Tourism Corridors (and Explore's Popular row)
- **Element:** the most-viewed stays, food places or corridors when that chip is chosen
- **Endpoint:** `GET /popular?interestIds=` then `GET /search/cards?ids=`; browses go in through `POST /popular/events`
- **Today:** `destinations[].destinationId` only; `POST /popular/events` takes a `destinationId`, so stay, food and corridor pages cannot be counted, and those chips can only show attractions tagged with the group's interests
- **Needed:** a `type` parameter on `GET /popular` (DESTINATION, STAY, FOOD, CORRIDOR) answering `items: [{type, id, browses, reason}]`, and `POST /popular/events` accepting `{targetType, targetId, eventType, sessionId}`
- **Why:** choosing Stays or Food on the Popular page shows no stays or food places, only attractions or nothing
- **Blocks the screen:** no, the chips send the group's interest ids and show what `/popular` returns
- **Status:** built 2026-10-14, `GET /popular?type=DESTINATION|STAY|FOOD|CORRIDOR` (destinations when left out) → `type` and `items: [{type, id, browses, reason}]` (`destinations[]` filled only for DESTINATION); `POST /popular/events` takes `{targetType, targetId, eventType, sessionId}` (`destinationId` still accepted as a destination's id)

### R-040 · Food detail · opening hours format
- **Screen:** Food detail, the open/closed pill under the name and the hours list
- **Element:** "● Open now · Closes 10PM" and the week's hours, Monday to Sunday
- **Endpoint:** `GET /foods/{id}`
- **Today:** `openingHours` (object, string → string), free text; neither the day keys ("MONDAY", "mon", "Mon-Fri"?) nor the hours format ("07:00-22:00", "7am–10pm", "Closed", two stretches?) is documented, and no food place on the server has any yet
- **Needed:** a documented shape, e.g. `openingHours: {"MONDAY": [{"open": "07:00", "close": "22:00"}], "TUESDAY": [], ...}` (an empty list = closed, close before open = past midnight), or the documented string format, plus `openNow` (boolean) computed in Cambodia time like R-009
- **Why:** the app has to guess how staff type the hours; text it cannot read shows as typed with no open/closed pill
- **Blocks the screen:** no, the app reads the common shapes and shows other text as typed
- **Status:** built 2026-10-14, the shape is `openingHours: {"mon": "07:00-22:00", …, "sun": "closed"}`: keys `mon`…`sun`, a day missing or `closed` is shut, one range `HH:mm-HH:mm` (a close before its open runs past midnight, `24:00` is midnight), and the API refuses anything else on write; plus `openNow` (boolean, null when no hours) and `todayHours` on `GET /foods/{id}`, computed in Cambodia time

### R-041 · Destination detail · stays and food nearby as cards
- **Screen:** Destination detail (attraction), the "Stays nearby" and "Food nearby" rows; Food detail, "Food nearby"
- **Element:** small cards with photo, name, rating and review count
- **Endpoint:** `GET /stays?near={destinationId}`, `GET /foods?near={destinationId}`
- **Today:** a list of full stay / food details (not paged); a stay detail has no rating or review count, so its card shows none
- **Needed:** the card (`PlaceCard`, as `GET /search/cards`) for each, e.g. `GET /search?type=STAY&near={destinationId}` → `{content, page}` of cards, nearest first
- **Why:** every list is made of the card; with details the stay rows have no score and would need a `GET /ratings/summary` per row
- **Blocks the screen:** no, the rows show photo, name and the stay type (food: its own averageRating, reviewCount, priceRange)
- **Status:** built 2026-10-14, `GET /search?type=STAY&near={destinationId}` and `type=FOOD&near=` → `{content, page}` of cards nearest first (the Nearby radius, the stay card has no rating until stays are reviewed, then it does); also `type=DESTINATION&near=` (attractions within 25 km, nearest first) and `type=CORRIDOR&near=` (corridors stopping there); the other filters still apply. 2026-10-16: `radiusKm=` (0.1 to 50) narrows or widens the attraction radius, and each attraction card found around a destination carries `distanceMeters`

### R-042 · All reviews · filter by star rating
- **Screen:** Reviews (Show all), list
- **Element:** the "All (500)" menu with 5 ★ … 1 ★ and each one's count, which narrows the list
- **Endpoint:** `GET /reviews?targetType=&targetId=&page=&size=`, `GET /ratings/summary`
- **Today:** `GET /reviews` takes `targetType`, `targetId`, `status`, `userId`, `page`, `size`, `sort`; no rating filter. The counts per star exist in `GET /ratings/summary` → `stars`
- **Needed:** a `rating` parameter (integer 1–5) on `GET /reviews`, e.g. `GET /reviews?targetType=DESTINATION&targetId=…&rating=5`
- **Why:** the list is paged, so filtering the loaded page on the phone would show a wrong, partial list
- **Blocks the screen:** no, the menu is left out and the chip shows the total
- **Status:** built 2026-10-14, `rating` on `GET /reviews` (integer 1–5, repeatable or `rating=4,5`): the reviews whose author gave the place that many stars; `page.totalElements` counts the filtered rows

### R-043 · All reviews · helpful votes
- **Screen:** Reviews (Show all), each review, signed in
- **Element:** the thumbs-up "Helpful" button under a review
- **Endpoint:** none
- **Today:** nothing; a review has no helpful count and there is no call to vote
- **Needed:** `PUT /reviews/{id}/helpful` and `DELETE /reviews/{id}/helpful` (signed in), and on the review `helpfulCount` (integer) and `helpfulByMe` (boolean)
- **Why:** a vote kept only on the phone is lost and counts for nobody
- **Blocks the screen:** no, the button is left out
- **Status:** declined: parked by Kimleng on 2026-10-14, no helpful votes yet; leave the button out

### R-044 · All reviews · report a review
- **Screen:** Reviews (Show all), each review's ⋮ menu, signed in
- **Element:** "Report review"
- **Endpoint:** none
- **Today:** nothing; only staff moderate reviews in the CMS
- **Needed:** `POST /reviews/{id}/reports` `{reason: "SPAM" | "OFFENSIVE" | "OFF_TOPIC" | "OTHER", note?: string}` (signed in), answering 201
- **Why:** a traveller has no way to flag an abusive or fake review
- **Blocks the screen:** no, the menu is left out
- **Status:** declined: parked by Kimleng on 2026-10-14, reports need a staff queue in the CMS first; leave the menu out

### R-060 · Profile · first and last name
- **Screen:** Profile → Account info and Edit profile, signed-in, editing
- **Element:** two inputs, First name and Last name
- **Endpoint:** `GET /users/me`, `PUT /users/me`
- **Today:** `fullName` (string), one value: "Dara Chan"
- **Needed:** `firstName` and `lastName` (string each, e.g. "Dara" and "Chan") on the answer and the `PUT` body, or the design keeps one "Full name" input
- **Why:** splitting one string on a space gets Khmer and multi-word names wrong, so the design's two inputs cannot be filled honestly
- **Blocks the screen:** no, one "Full name" input shows and saves `fullName` meanwhile
- **Status:** declined: the design keeps one "Full name" input, as the example entry suggested: a Khmer or multi-word name cannot be split honestly, and `fullName` is what Keycloak and the CMS carry; first and last name stay in the sign-in account only

### R-061 · Profile · home province
- **Screen:** Profile header (signed-in), Account info and Edit profile (editing)
- **Element:** the traveller's province or capital: a line under the name ("Phnom Penh, Cambodia") and a "Province / Capital" picker in the forms
- **Endpoint:** `GET /users/me`, `PUT /users/me`
- **Today:** nothing; the account has `fullName`, `email`, `phone`, `avatarKey`, `avatarUrl`, `createdAt` only
- **Needed:** `homeProvinceId` (uuid from `GET /provinces`, nullable) on the answer and the `PUT` body, and ideally `homeProvinceName` (string, e.g. "Phnom Penh") on the answer
- **Why:** the location line and the province picker have nowhere to read or save the value
- **Blocks the screen:** no, the line and the picker are hidden meanwhile
- **Status:** built 2026-10-14, `homeProvinceId` (uuid from `GET /provinces`) on `PUT /users/me` (the whole profile is sent, so leaving it out clears it; an unknown id is a 400) and `homeProvinceId` + `homeProvinceName` on `GET /users/me`

### R-062 · Profile · profile completion
- **Screen:** Profile, signed-in, the header card
- **Element:** "80% profile completed" in green under the joined date
- **Endpoint:** `GET /users/me`
- **Today:** nothing; no completion score, and the app may not invent its own formula
- **Needed:** `profileCompletion` (integer 0–100, e.g. 80) on `GET /users/me`, computed by the server from the fields it decides count
- **Why:** the line cannot be shown without a number the backend stands behind
- **Blocks the screen:** no, the line is hidden meanwhile
- **Status:** built 2026-10-14, `profileCompletion` (0–100) on `GET /users/me`: name, email, phone, picture and home province count 20 each

### R-063 · Preferences · distance unit
- **Screen:** Profile → Preference → Unit, signed-in
- **Element:** the choice Kilometers / Meters (km/m) or Miles / Feet (mi/ft)
- **Endpoint:** `GET /preferences/me`, `PUT /preferences/me`
- **Today:** `preferredLanguage`, `preferredCurrency`, `preferredRegionId`, `notificationEmail`, `notificationPush`, `theme`; no unit
- **Needed:** `distanceUnit` (string, `KM` or `MI`, default `KM`) on the answer and the `PUT` body
- **Why:** the unit is the one preference that does not follow the traveller to another phone
- **Blocks the screen:** no, the unit is kept on the phone meanwhile
- **Status:** built 2026-10-14, `distanceUnit` (`KM` or `MI`) on `GET /preferences/me` and `PUT /preferences/me`; `KM` when left out of the `PUT`

### R-064 · Badges · standing among members
- **Screen:** Badges, signed-in, the current status card
- **Element:** "Top 5% of active members" under the badge
- **Endpoint:** `GET /badges/me/progress`
- **Today:** tracks, badges and earned for the traveller; nothing compares them with other members
- **Needed:** on the progress answer `percentile` (integer 1–100, e.g. 5 for the top 5%, null when the traveller has no activity this season), computed over the season's active members
- **Why:** the ranking line cannot be shown, and the phone cannot see other members' progress
- **Blocks the screen:** no, the line is hidden meanwhile
- **Status:** built 2026-10-14, `percentile` (integer 1–100, null when the traveller has no progress this season) on `GET /badges/me/progress`: members with any progress in the season are ranked by badges earned, then by progress added up over every ladder; 5 means the top 5%

### R-065 · Reviews (mine) · filter by stars
- **Screen:** Profile → Reviews, signed-in, the list
- **Element:** the filter button beside "Sort by" that shows only the 5★ (or 4★, …) reviews
- **Endpoint:** `GET /reviews/me?page=&size=&sort=`
- **Today:** paging and sort only; no rating filter
- **Needed:** a `rating` parameter (integer 1–5, repeatable), e.g. `GET /reviews/me?rating=5`, with `page.totalElements` counting the filtered rows
- **Why:** the app may not filter on the phone, and a page of 20 cannot show "all my 5★ reviews"
- **Blocks the screen:** no, the filter button is hidden meanwhile
- **Status:** built 2026-10-14, `rating` (integer 1–5, repeatable or comma-separated) on `GET /reviews/me`; `page.totalElements` counts the filtered rows

### R-066 · Achievement · link to a shared badge
- **Screen:** Badges → Achievement, signed-in, an earned badge
- **Element:** "Share to Facebook": the post links to a page showing the badge and its holder
- **Endpoint:** `GET /badges/shared/{userBadgeId}` (public page data)
- **Today:** the data of the share page; no public web address that renders it, so there is nothing to link
- **Needed:** the web address pattern of the share page, e.g. `https://travel.ams.com.kh/badges/{userBadgeId}`, or a `shareUrl` (string) on each row of `GET /badges/me/earned`
- **Why:** Facebook's share needs a link; without it the share carries only text
- **Blocks the screen:** no, the badge is shared as text (name and season) through the phone's share sheet meanwhile
- **Status:** built 2026-10-14, `shareUrl` on every earned badge row (`GET /badges/me/earned`, `GET /badges/shared/{userBadgeId}`, `earned[]` of the progress answer; null until earned): `https://api.travel.ams.com.kh/api/v1/badges/shared/{userBadgeId}/page`, a public HTML page with the badge, its holder and season and the Open Graph tags Facebook reads for its card

### R-067 · Explore · the seal on a Tourism Region card
- **Screen:** Explore, "Explore by Tourism Region" row; Regions list
- **Element:** under the region name on the photo, the green check and "Recommend by AMS Travel", the same seal the destination rows carry
- **Endpoint:** `GET /regions?kind=TOURISM`
- **Today:** `id`, `name`, `code`, `kind`, `parentId`, `description`, `coverKey`, `coverUrl`, `categoryIds`, `tagIds`, `interestIds`, `sortOrder`, `latitude`, `longitude`, `centreSet`, `bounds`, `isActive`, `createdAt`; nothing about verification. `GET /search/cards` has `verified`, but only for a destination, stay, food place or corridor — a region id returns `[]`
- **Needed:** on each region `verified` (boolean), and if it is decided by its places rather than set in the CMS, `verifiedPlaceCount` (integer) so the card can say how many, e.g. `true`, `12`
- **Why:** the card has no way to show the seal; the app cannot derive it without reading every place of every region
- **Blocks the screen:** no, the card shows the photo and the name, and the seal appears by itself once the field arrives
- **Status:**

### R-068 · Search · the `verified` filter is not applied
- **Screen:** any list built on search (Popular, interest and region lists, the seal panels)
- **Element:** a list of only the places that carry the AMS Travel seal
- **Endpoint:** `GET /search?verified=true`
- **Today:** the answer is the unfiltered list — `GET /search?verified=true&size=5` comes back with Angkor Golf Resort (`verified: true`) followed by Angkorian Royal Road and Angkor Wat, both `verified: false`. `travelerRecommended=true` does filter (it answers with an empty list)
- **Needed:** `verified=true` returns only rows whose `verified` is true, the way `travelerRecommended` does
- **Why:** any panel of seal holders would show places without the seal
- **Blocks the screen:** no, the app does not use the filter today
- **Status:**

### R-069 · Past season · thresholds and standing as the season left them
- **Screen:** Badges → Past seasons → one season, signed-in, read-only
- **Element:** each ladder's levels with "Gold · 800 browse" beside a tick or a "512 / 800 · not finished" bar, and "Finished in the top 12% of active members"
- **Endpoint:** `GET /badges/me/progress?seasonId={id}`
- **Today:** unknown. The answer has `tracks[].thresholds`, `badges[].threshold` and `percentile`, but the docs do not say whether they are kept from the season or worked out again from today's `GET /badges` definitions and today's members
- **Needed:** for a COMPLETED season, `tracks[].thresholds`, `badges[].threshold` and `percentile` as they stood when the season ended, unchanged if a definition is edited later; or a word that they are already kept, e.g. `thresholds: {"SILVER": 300, "GOLDEN": 800, "PLATINUM": 1000}` staying 300 after Silver is raised to 400
- **Why:** an edited threshold would make an old season say a level needed more than it did, or show a finished ladder as unfinished
- **Blocks the screen:** no, the page reads the badge row's `threshold` first, then the track's, then today's definition
- **Status:** requested 2026-10-20

### R-070 · Past seasons · browses, check-ins and badges per season
- **Screen:** Badges → Past seasons, signed-in, the list
- **Element:** each season card: points, then what the traveller did in it and how many badges it gave them
- **Endpoint:** `GET /seasons/me/history`
- **Today:** `points`, `ratingCount`, `reviewCount`, `uniqueRatedTargetCount`, `uniqueReviewedTargetCount`, `startedAt`, `updatedAt`; no browses, no check-ins, no badge count, no season dates
- **Needed:** on each row `browseCount`, `stampCount`, `badgeCount` (integers) and `startsOn`, `endsOn` (dates), e.g. `512`, `0`, `1`, `2025-11-01`, `2026-04-30`
- **Why:** the browse and check-in ladders only appear in one `GET /badges/me/progress?seasonId=` call per season, and the badge count and dates take two more calls (`GET /badges/me/earned`, `GET /seasons`) for one list
- **Blocks the screen:** no, the card shows points, reviews, ratings and places from the history, the badges counted from `GET /badges/me/earned` and the dates from `GET /seasons`
- **Status:** requested 2026-10-20

### R-071 · Stay · the Recommended seal under the name
- **Screen:** Stay detail, under the hotel's name
- **Element:** the green "Recommend by Traveler" / "Recommend by AMS Travel" seal, as on an attraction
- **Endpoint:** `GET /search/cards?ids=&type=STAY`
- **Today:** the stay's card has `travelerRecommended` and `verified`, but stays carry no Traveler seal (R-033: "stays, food and corridors carry no seal"), so the line never shows for a stay
- **Needed:** the Traveler seal (`travelerRecommended`) worked out for stays too, and `verified` set for stays AMS recommends
- **Why:** the design shows the seal under a hotel's name the same way as under an attraction's
- **Blocks the screen:** no, the line is left out while neither flag is set
- **Status:** requested 2026-10-20

### R-072 · Search · places along a corridor
- **Screen:** Search, Filters sheet, the Corridors tab
- **Element:** picking one or more corridors, so the results are the places along them
- **Endpoint:** `GET /search`
- **Today:** no corridor filter; a corridor's stops are only in `GET /corridors/{id}/itinerary` and on its card (`stopNames`), so "places on the Khmer Civilization route" cannot be asked
- **Needed:** `corridorIds` (comma-separated uuid list, any of them matches) on `GET /search`: the corridors' stop destinations, and the stays and food near those stops when `type=STAY|FOOD`, e.g. `GET /search?corridorIds=a,b&type=DESTINATION`
- **Why:** the sheet offers corridors next to regions, provinces and interests
- **Blocks the screen:** no, the app already sends `corridorIds`; until the server reads it the picks do not narrow the results or the count on Apply
- **Status:** requested 2026-10-21

### R-073 · Search · categories and tags for the picked filters
- **Screen:** Search, Filters sheet, the Categories and Tags sections
- **Element:** only the categories and tags that go with what is picked along the top (provinces, interests, corridors)
- **Endpoint:** `GET /categories`, `GET /tags`
- **Today:** tourism regions list their own `categoryIds` and `tagIds`, so the sheet narrows to those; provinces, interests and corridors carry none, so with only those picked the sheet shows every category and tag
- **Needed:** the categories and tags of the places matching a set of filters, e.g. `GET /search/facets?provinceIds=&interestIds=&corridorIds=&regionIds=` → `{"categoryIds": ["…"], "tagIds": ["…"]}` (or the same with counts)
- **Why:** a category with no place under the picks gives "No matches" when tapped
- **Blocks the screen:** no, the sheet shows all categories and tags unless a tourism region is picked
- **Status:** requested 2026-10-21

### R-074 · Detail pages and cards · the short description in Khmer
- **Screen:** attraction, stay, food place and activity detail, the Overview card; every list row's line under the name; app language on Khmer
- **Element:** the first paragraph of the Overview card (and the one-line summary on cards), in Khmer
- **Endpoint:** `GET /destinations/{id}`, `GET /stays/{id}`, `GET /foods/{id}`, `GET /activities/{id}`; `GET /search?lang=km`, `GET /search/cards?lang=km`
- **Today:** the Khmer twins are `nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm`; `shortDescription` has no twin, and the cards asked `lang=km` keep it in English even where the rest is Khmer (Kampi Dolphin Sunset Cruise: name and province in Khmer, `shortDescription` "A two-hour evening cruise…", `untranslated: []`)
- **Needed:** `shortDescriptionKm` (string, null when not written) on the four detail answers, and the card's `shortDescription` in Khmer under `lang=km` (named in `untranslated` when it is not), e.g. `"shortDescriptionKm": "ជិះទូកពីរម៉ោងពេលល្ងាច…"`
- **Why:** the page opens on an English paragraph under a Khmer title, even when every other field was written in Khmer
- **Blocks the screen:** no, the English short description shows meanwhile
- **Status:** requested 2026-10-21

### R-075 · Explore, Interests, Search · the interest groups in Khmer
- **Screen:** the six group chips (Explore, Interests, Provinces, Popular, Map, the Filters sheet) and the search field's "Search activities & experiences"; app language on Khmer
- **Element:** the group names: Attraction Sites, Stays, Food, Water, Activities & Experiences, Tourism Corridors
- **Endpoint:** `GET /interests`
- **Today:** each interest has `nameKm` and `descriptionKm`, but its group is only `groupName` in English, so the chip row stays English above Khmer interest chips
- **Needed:** `groupNameKm` (string) on each interest, the same for every interest of a group, e.g. `"groupName": "Activities & Experiences", "groupNameKm": "សកម្មភាព និងបទពិសោធន៍"`
- **Why:** with the app in Khmer the top chip row and the search hint are the only content left in English
- **Blocks the screen:** no, the group names show in English meanwhile
- **Status:** requested 2026-10-21

### R-077 · Search · results of every kind when no kind is picked
- **Screen:** Search, results for a keyword, no kind picked in the Filters sheet
- **Element:** the "n found" count and the result list under the typing suggestions
- **Endpoint:** `GET /search?q=`, `GET /search/suggest?q=`
- **Today:** with no `type`, `GET /search` answers attractions only, while `GET /search/suggest` answers every kind: `q=tatai` suggests Tatai River Ecolodge (STAY) and Tatai Waterfall (DESTINATION), but `GET /search?q=tatai` → `totalElements: 1`, only the waterfall; `GET /search?q=tatai&type=STAY` does find the ecolodge
- **Needed:** `type` left out means every kind (DESTINATION, STAY, FOOD, ACTIVITY, CORRIDOR) in one paged answer, each card with its `type`, e.g. `GET /search?q=tatai` → `totalElements: 2`, the ecolodge and the waterfall
- **Why:** the screen shows two suggestions over "1 found", and a keyword matching only a stay, food place, activity or corridor answers "No matches"
- **Blocks the screen:** no, the suggestions above the results still open the other kinds
- **Status:** requested 2026-10-22
