# Round 2 for Claude Code (2026-10-16)

Developer: delete the folder where our API docs sit in your app repo and unzip this bundle in its place, then
tell Claude Code `Read CLAUDE-PROMPT-2.md and do what it says.` Everything below the line is for Claude Code.

---

The AMS Travel API answered our `API-REQUESTS.md`: of the 29 entries, 23 are built and 6 are parked or
declined. The folder that holds this file was just replaced with the backend team's new bundle (it is written
`api-docs/` below; if yours carries another name, read that folder wherever `api-docs/` appears): every file
in it is newer than what you read before, so read them again now and trust them over anything you remember or
noted from the old folder. It stays the source of truth. Read, in this order:
1. `api-docs/API-REQUESTS.md`: every entry now has a **Status** line. `built 2026-10-14, …` names the exact
   field or endpoint; `declined: …` says why, and whether it is parked.
2. `api-docs/screens-to-api.md`: the rows are updated to the new fields and endpoints, and the section
   "What changed on 2026-10-14" at the top sums it up.
3. `api-docs/postman/`: re-import both files; the collection has 81 requests now, one for every new call.

Added 2026-10-16 (same folder, newer than the answers above; `screens-to-api.md` has the note "What changed
on 2026-10-16"): `GET /search?type=DESTINATION&near=` takes `radiusKm` (0.1 to 50; 25 when left out) and every
attraction card found that way carries `distanceMeters`, null on other cards; every interest answers
`coverUrl` (its picture; keep `iconKey` as the fallback); every tourism region answers `mapUrl` (ONE picture
for the Map panel of its page, in place of an interactive map of its places) and `amsRecommended` (show the
"Recommended by AMS Travel" badge on its card and page). A destination's `theme` may be any tourism region's
code. There is no `history` data and no `historical-coverage` endpoint: build nothing on them. The staging
catalogue was reseeded on 2026-10-16, so every id changed: clear caches and saved test data first.

First check that the server runs the new API. The checks:
`GET https://api.travel.ams.com.kh/api/v1/provinces` answers `coverUrl` and `placeCount` on each province,
and `GET /popular?limit=3` answers `items[]` with a `reason`. Until both do, change nothing and tell me.

Then work through `API-REQUESTS.md` from top to bottom:
- For every entry marked **built**: find its `TODO R-nnn` in the app, replace the degraded behaviour with
  what the Status line names, and remove the TODO. Show me the screen working against the server.
- For every entry marked **declined** (R-004 Khmer content, R-006 riel prices, R-008 folders, R-043 helpful
  votes, R-044 reporting, R-060 the name split): keep the degraded behaviour, turn the TODO into a short
  note `parked 2026-10-14` or `declined 2026-10-14`, and do not ask again.
- Copy the answered file over the one at the root of this repo. New needs go after R-066 with new numbers,
  in the same shape, and no answered entry is ever deleted.

What changed in shape, beyond new fields:
- `GET /popular` now answers `{days, regionId, type, items: [{type, id, browses, reason}], destinations}`.
  Read `items`; `destinations` is the old shape and is filled only for `type=DESTINATION`. The row is never
  empty: after the browsed places come filler rows with `reason` VERIFIED, TOP_RATED or CATALOGUE and
  `browses` 0. `POST /popular/events` takes `{targetType, targetId, eventType, sessionId}` for any kind of
  page; `destinationId` still works for an attraction.
- `PUT /users/me` carries the whole profile: send `fullName`, `phone`, `avatarKey` and `homeProvinceId`
  every time, a field left out is cleared.
- `GET /search`: `regionIds` and `provinceIds` take several ids; a region id may be a zone or a tourism
  region; `travelerRecommended=true` keeps the seal holders (empty until a place reaches 10,000 ratings at
  4.5: hide the panel while `content` is empty); `near={destinationId}` orders the cards nearest first; a
  CORRIDOR card carries `stopNames` and `encodedPolyline` (about 11 KB per corridor, five corridors);
  a FOOD card carries `openNow` and `todayHours`.
- `GET /search/by-province` is the Provinces page in one call; `GET /provinces` and `GET /regions` carry
  `latitude`, `longitude` and `bounds` for the Map markers; `GET /media?ownerType=CORRIDOR&ownerId=` is the
  corridor gallery; `GET /reviews` and `GET /reviews/me` take `rating=`; `GET /badges/me/progress` has
  `percentile`; every earned badge row has `shareUrl`, a public web page for the share sheet.
- Food hours: `openingHours` keys are `mon`…`sun`, a value is `07:00-22:00` or `closed`, a missing day is
  shut, a close before its open runs past midnight, `24:00` is midnight. Every food answer also carries
  `openNow` and `todayHours` computed on the server in Cambodia time, so the app never computes them.
- Favourites: `targetType` REGION and PROVINCE work on the three favourites calls, for the hearts on the
  Explore cards and the Saved tabs.

Decided and not changing: sign-in, sign-up, the email code and forgot-password stay Keycloak's pages opened
through AppAuth (authorization code with PKCE, client `amstravel-mobile`, redirect `amstravel://callback`).
Build no sign-in form and call no endpoint for it.

Order of work: the Explore screen (province cards with picture, score and count; popular rows from
`items`), then Search (several regions and provinces, the seal filter, nearby as cards), the Provinces page
(`by-province`), the Map (province and region markers, every corridor line at once), Corridors (stops on
the card, the gallery), Stays and Food (nearby cards, open now), Reviews (the star filter on both lists),
Profile and Preferences (home province, completion, distance unit), Badges (percentile, share link). Show
me each screen against the server before the next, and at the end list which `TODO R-nnn` remain and why.
