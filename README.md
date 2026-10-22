# AMS Travel — Mobile

Flutter app for AMS Travel: Cambodia by tourism region, interest, province and
corridor, with place details, maps, saves, check-ins, badges and reviews.
English and Khmer.

The app runs on the **AMS Travel API** on the company server. Nothing from the
backend runs on your machine.

| Piece | Address |
|---|---|
| API | `https://api.travel.ams.com.kh/api/v1` (Swagger UI at `/swagger-ui/index.html`) |
| Sign-in | Keycloak realm `https://auth.travel.ams.com.kh/realms/amstravel`, client `amstravel-mobile` |

The backend team's documents are in `assets/docs/mobile/`: `README.md` (addresses,
sign-in, conventions), `screens-to-api.md` (every screen and the call behind each
element) and `postman/` (a request for every call).

## Run

```sh
flutter pub get
flutter run
```

Open straight on a screen during development:

```sh
flutter run --dart-define=INITIAL_ROUTE=/places/bf87218d-ab3f-40d3-8065-f9ae3aac41c5
```

Point the app at another server: `--dart-define=API_ORIGIN=https://…` and
`--dart-define=AUTH_ISSUER=https://…/realms/amstravel`.

Tests answer from saved server responses in `test/fixtures/api/`, never the
network:

```sh
flutter test
```

## How the app talks to the API

- **Guest first.** Every read is public. A guest can browse everything; saving,
  reviewing, checking in, notifications and the profile ask to sign in.
- **Sign-in is Keycloak's.** Log in, register, the six-digit email code and
  forgot-password are Keycloak's own pages, opened in the system browser through
  AppAuth (authorization code + PKCE, redirect `amstravel://callback`). The app
  has no forms for them. Tokens live in the keychain / keystore
  (`flutter_secure_storage`), are refreshed before they expire and once more when
  the API answers 401; if that fails the traveller is signed out and the request
  is repeated as a guest. After sign-in the app reads `GET /users/me` and
  `GET /preferences/me`.
- **One card for every list.** Rows come from `GET /search` and
  `GET /search/cards`; a row never makes a second call. Paged answers are
  `{content, page}`.
- **The server filters.** Search, filters, suggestions, nearby and popular are
  all server calls; the app never filters the catalogue itself.
- **Pictures** are paths; the models put the server origin in front.
- **Stays** show one total for the chosen nights from `GET /stay-rooms/quote`,
  never a nightly price. There is no booking: the stay's phone and website are
  offered instead.
- **Reviews** upload their photos with `POST /media/files` (type `review`), then
  send one `POST /reviews`.
- **Check-in** scans the QR code a place posts on site (or takes the code typed
  from under it) and sends it with the phone's position in one `POST /stamps`;
  location is asked for at that moment. The result is for the place the code
  belongs to, whatever page the scanner was opened from.
- **Khmer content.** With the app in Khmer the search calls ask `lang=km`, and
  `AmsApi` reads each `…Km` twin of a detail or reference answer in place of the
  English, which stays where no Khmer is written. A language change rebuilds the
  open pages, so they read their content again.

## When the API is missing something

The app does not work around a gap on the phone. Each one is an entry in
[`API-REQUESTS.md`](API-REQUESTS.md) (R-001, R-002, …), and the code marks the
spot with `TODO R-nnn`, hiding the element or showing what the API has. Kimleng
takes that file to the backend; the backend answers in each entry's Status line.

```sh
grep -rn "TODO R-" lib
```

## Screens

| Tab / page | Route |
|---|---|
| Welcome | `/welcome` — the slides, then Start My Journey (Keycloak registration) or Explore as Guest |
| Explore | `/` — interest groups, tourism regions, popular, corridors, provinces |
| Search | `/search?q=` — suggestions, kind chips, filters, nearby, recent keywords |
| Popular | `/popular`, type-ahead at `/popular/search` |
| Tourism regions | `/regions/explore`, a region at `/regions/:id` |
| Provinces | `/provinces/explore`, `/provinces/:id`, `/provinces/:id/places` |
| Interests | `/interests/explore`, a group at `/interests/:group` (e.g. `attraction-sites`) |
| Corridors | `/corridors`, a corridor at `/corridors/:id` |
| Attraction | `/places/:id` — gallery, reviews, nearby, stays, food and activities near it, check-in |
| Stay | `/stays/:id`, rooms at `/stays/:id/rooms`, a room at `/stays/:id/rooms/:roomId` |
| Food | `/foods/:id` |
| Activity | `/activities/:id` — kind, interests, the organiser's contacts, check-in |
| Check-in | `/check-in`, the QR scanner (also from Profile → Check-ins) |
| Reviews | `/reviews/:type/:id`, write one at `/reviews/:type/:id/new` |
| Map | `/map`, `/map?place=<destination id>`, `/map?corridor=<corridor id>` |
| Saved | `/saved`, folders at `/folders/:name` |
| Profile | `/profile`, `/account`, `/profile/edit`, `/notifications` |
| Badges | `/badges`, `/badges/:badge`, `/badges/:badge/achievement`, past seasons at `/badges/seasons` |
| My reviews | `/my-reviews`, `/my-reviews/:id` |
| Preferences | `/preferences` and `/preferences/language\|currency\|units\|notifications` |
| Help & support / Terms | `/help`, `/terms` |

## Project layout

```
lib/
  core/
    config/api_config.dart     ← server origin, base URL, Keycloak settings, picture links
    network/api_client.dart    ← Dio: bearer token, refresh on 401, problem-JSON errors, uploads
    router/                    ← go_router; every page keyed by the API's ids
    utils/                     ← location, polyline decoding, opening hours, geo helpers
  data/
    api/ams_api.dart           ← one method per call in screens-to-api.md
    api/catalog.dart           ← the card, pages, regions, interests, provinces
    api/details.dart           ← place, stay, room, quote, food, corridor, itinerary, media
    api/account.dart           ← reviews, profile, preferences, favourites, badges, check-ins
    auth/keycloak.dart         ← AppAuth sign-in / registration / refresh / sign-out, token store
  state/                       ← session, favourites, notifications, locale, settings, folders
  features/                    ← one folder per area
  widgets/                     ← shared cards, rows, map, filters
test/
  fixtures/api/                ← saved server answers the tests read
  support/fake_api.dart        ← the fixture adapter and a fake Keycloak
```

## Before release

- **Map tiles:** the public OpenStreetMap server is for development only. Set
  `tileUrl` in `lib/widgets/map_view.dart` to a paid tile provider.
- **Bundle ID:** change `com.example.amsTravel` (iOS) and
  `com.example.ams_travel` (Android) to your own.
- **Share links:** sharing a place sends text and a map link; a web address for
  places and badges is needed for real links (R-066).
- **Help & Terms:** the support details and legal wording are placeholders from
  the design (`TODO(content)`).
- **App icon:** regenerate from `assets/icon/` with `dart run flutter_launcher_icons`.
