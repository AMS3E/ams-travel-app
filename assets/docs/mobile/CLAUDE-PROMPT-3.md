# Round 3 for Claude Code (2026-10-21)

Developer: delete the folder where our API docs sit in your app repo and unzip this bundle in its place, then
tell Claude Code `Read CLAUDE-PROMPT-3.md and do what it says.` Everything below the line is for Claude Code.

---

The folder that holds this file was just replaced with the backend team's new bundle (it is written
`api-docs/` below; if yours carries another name, read that folder wherever `api-docs/` appears). Every file
in it is newer than what you read before, so read them again now and trust them over anything you remember or
noted from the old folder. It stays the source of truth.

Four features shipped on the server since round 2 (2026-10-16). Read, in this order:
1. `api-docs/screens-to-api.md`: the sections "What changed on 2026-10-20" and "What changed on 2026-10-21"
   sum everything up; the new "Activities & Experiences" section and the Badges rows carry the detail.
2. `api-docs/API-REQUESTS.md`: **R-004 (Khmer content) changed from declined to `built 2026-10-21`.** The
   `declined 2026-10-14` note you left in the app no longer holds; build the real thing (feature 3 below).
3. `api-docs/postman/`: re-import both files (87 requests now). The check-in request's body changed.

**Before anything else, two checks against the server.** `GET https://api.travel.ams.com.kh/api/v1/badges`
must answer three ladders with `type` BROWSES, REVIEWS and STAMPS and no POINTS rows, and
`GET /api/v1/search?type=ACTIVITY&size=3` must answer cards with `type` ACTIVITY. Until both do, change
nothing and tell me.

**The staging catalogue was reseeded on 2026-10-21, so every id changed since round 2.** Clear caches and
saved test data first; nothing created on the staging server survives a reseed.

## The four features, in the order to build them

**1. Check-in by QR code (the Adventure badge's screen).** A place posts a printed QR on site; checking in
needs that code scanned AND the phone standing there.
- Put the scan action where the design wants it (on a place's page, and any general scan button). The QR
  encodes a link like `https://api.travel.ams.com.kh/api/v1/stamps/scan/ABCD-EFGH-JKLM`; outside the app a
  phone camera lands on a plain web page, inside the app read the whole scanned text. Under each printed QR
  the code is also written in letters, so offer a way to type it when the camera fails.
- `POST /stamps` `{code, latitude, longitude}` (signed in): send the scanned text (or the typed code) and
  the device position. Ask for location permission at this moment, not before. `destinationId` is gone from
  this call.
- **The response names the place, never the screen.** A place may post several codes at once (the gate, a
  brochure), and any scan button may scan any place's code: show the result for the response's `targetType`
  and `destinationId`, even when the scanner was opened from another place's page.
- Outcomes: COLLECTED (show the stamp and any `badgesEarned`); ALREADY_COLLECTED (one stamp per place per
  SEASON now, not per day); TOO_FAR (say how far: `distanceMeters` against `radiusMeters`); INVALID_CODE
  (the print is unknown or retired: say to ask the staff on site for the current code).
- `GET /stamps/me` lists the collected stamps, each with `targetType` DESTINATION / STAY / FOOD / ACTIVITY.

**2. Badges: three ladders, and past seasons.** The Explorer (POINTS) ladder is retired: `GET /badges` and
`GET /badges/me/progress` answer Browser, Reviewer and Adventure only — remove whatever the app shows for a
points ladder. Points still exist as season totals (`GET /points/me`). New screens for history:
- a "Past seasons" entry on the badges screen: `GET /seasons/me/history` (the traveller's totals per season,
  newest first), with `GET /seasons` (public) for the picker;
- tapping a season opens its ladders read-only: `GET /badges/me/progress?seasonId=` (same shape as the
  current-season call; without `seasonId` it answers the active season, as now);
- `GET /badges/me/earned` mixes seasons: group or label the list by `seasonName`. Each row's `shareUrl`
  works for old badges too.

**3. Khmer content (R-004, now real).** With the app's language on Khmer: ask `?lang=km` on `GET /search`,
`/search/by-province`, `/search/suggest` and `/search/cards` — cards and suggestions come in Khmer where
written, and `untranslated` names the fields still in English. Detail answers carry the Khmer beside the
English: `nameKm`, `descriptionKm`, `sloganKm`, `sloganByKm`, `addressKm` on attractions, stays, food places
and activities; `nameKm` (and `descriptionKm` on regions and interests) on provinces, regions, categories,
tags and interests. Fall back to the English field when the Khmer one is null — Khmer is optional on the CMS
side. Search matches Khmer names and addresses whatever the `lang`. Replace the `declined 2026-10-14` note
and its degraded behaviour with this.

**4. Activities & Experiences, the fourth kind of destination.** Something a traveller does rather than
visits (a dive trip, a kayak tour, a trek, a cruise). The "Activities & Experiences" section of
`screens-to-api.md` is the spec: `GET /search?type=ACTIVITY` with the ten chips as `interestIds`,
`GET /activities/{id}` with `type`, the contact fields (phone, e-mail, website, Telegram, WhatsApp,
Facebook) and the Khmer twins, and `targetType`/`ownerType` ACTIVITY on reviews, ratings, favorites,
stamps, browse events, media and the verification status. An activity has no price, duration or opening
hours for now. The staging seed ships five to build against.

## Smaller changes to pick up while you are in there

- Verified for every kind: `verified`, `basis` and `travelerRecommended` on stay and food cards are real
  values now (they were always false before) — whatever the app hid or hard-coded there can show.
- `viewCount` on `GET /stays/{id}`, `GET /foods/{id}` and `GET /activities/{id}`, like attractions; the
  Browser badge's `PUT /badges/me/explorations/{id}` takes any kind's id.

Decided and not changing: sign-in, sign-up, the email code and forgot-password stay Keycloak's pages opened
through AppAuth (authorization code with PKCE, client `amstravel-mobile`, redirect `amstravel://callback`).
Build no sign-in form and call no endpoint for it.

Work as before: show me each screen working against the server before the next. New needs go into
`API-REQUESTS.md` after the last number with new numbers, in the same shape; no answered entry is ever
deleted. At the end, list which `TODO R-nnn` remain and why.
