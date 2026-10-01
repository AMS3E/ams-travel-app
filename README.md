# AMS Travel — Mobile

Flutter app for [ams-travel.netlify.app](https://ams-travel.netlify.app/): Cambodia by
tourism region, interest, province and corridor, with verified place details,
maps, saved lists, stamps and reviews. English and Khmer.

The app currently runs on **mock data** (`assets/mock/*.json`, taken from the
website) until the backend API is ready.

## Run

```sh
flutter pub get
flutter run
```

Open straight on a screen during development:

```sh
flutter run --dart-define=INITIAL_ROUTE=/regions/ancient-capitals/angkor-wat
```

Tests (mock data parses through the real models, plus a UI smoke test):

```sh
flutter test
```

## Screens

| Tab / page | Route |
|---|---|
| Welcome / onboarding | `/welcome` — slides, interests step, "journey is ready" |
| Home (the Explore tab) | `/` — regions, popular, corridors, interests, provinces, reviews |
| Browse by region | `/regions/explore` — the nine regions and what they hold |
| Region place list | `/regions/:region/places` — every place in one region |
| Popular | `/popular` — the best known places in one list |
| Type-ahead search | `/popular/search` — matches as you type, then suggestions |
| Browse by interest | `/interests/explore` — one category at a time, plus what travellers recommend |
| Browse by province | `/provinces/explore` — filtered by interest, with Show all 25 provinces |
| Province place list | `/provinces/:province/places` — every place in one province |
| Explore lists | `/explore?tab=regions\|interests\|provinces\|corridors` — pushed from the corridors arrow, not a tab |
| Map | `/map`, `/map?place=region/slug` — layers for provinces, interests and corridors |
| Saved | `/saved`, folders at `/folders` and `/folders/:name` |
| Profile | `/profile` |
| Region | `/regions/:region` |
| Destination (all categories) | `/regions/:region/:slug` |
| Write a review | `/regions/:region/:slug/review` |
| Rooms (stays) | `/regions/:region/:slug/rooms`, `/regions/:region/:slug/rooms/:roomId` |
| Story | `/regions/:region/stories/:slug` |
| Province | `/provinces/:slug` |
| Interest | `/interests/:slug` — one category across the regions |
| Corridor | `/corridors/:slug` — stops, day-by-day plan |
| Search | `/search?q=` |
| Badges | `/badges`, `/badges/:badge` (achievement page) |
| My reviews | `/my-reviews` |
| Account info | `/account` |
| Preference | `/preferences` and `/preferences/language\|currency\|units\|notifications` |
| Help & support / Terms | `/help`, `/terms` |
| Auth | `/login`, `/register`, `/forgot-password` |

## Project layout

```
lib/
  core/
    config/api_config.dart     ← mock/API switch, base URL, every endpoint path
    network/api_client.dart    ← Dio: auth header, timeouts, error messages
    l10n/app_strings.dart      ← English + Khmer UI text
    theme/                     ← website colours (brand / sunset / sand), fonts
    router/                    ← go_router routes (same paths as the website)
  data/
    models/                    ← Destination, Region, Province, Interest, Corridor, Story, Review, User
    repositories/
      travel_repository.dart   ← interface the screens use
      mock_travel_repository.dart
      api_travel_repository.dart
      auth_repository.dart     ← mock + API auth
  state/                       ← auth session, saved list, folders, stamps, badges,
                                 interests, language, settings (Provider)
  features/                    ← one folder per screen
  widgets/                     ← shared UI (cards, map, image, loading/error)
assets/
  mock/                        ← JSON in the shape the API is expected to return
  google_fonts/                ← Geist (all weights), bundled so text works offline
```

## Connecting the real API

Screens never call HTTP directly. They use `TravelRepository` and
`AuthRepository`, so switching to the backend touches only the data layer:

1. **Turn off mock data.** In `lib/core/config/api_config.dart` set
   `useMockData = false` and `baseUrl`, or pass them at build time:
   `flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://…`
2. **Match the routes.** Edit the paths in `ApiEndpoints` (same file). These
   are the only calls the app makes:

   | Method | Path | Used by |
   |---|---|---|
   | GET | `/regions`, `/regions/:slug` | home, explore, region page |
   | GET | `/regions/:region/stories` | Ancient Capitals stories |
   | GET | `/regions/:region/reviews` | reviews on a region |
   | GET | `/destinations?region=&province=&category=&q=` | every list of places |
   | GET | `/regions/:region/destinations/:slug` | place detail |
   | GET | `/regions/:region/destinations/:slug/reviews` | reviews on a place |
   | POST | `/regions/:region/destinations/:slug/reviews` | write a review |
   | GET | `/regions/:region/destinations/:slug/rooms` | rooms in a stay |
   | GET | `/provinces`, `/provinces/:slug` | province pages |
   | GET | `/interests` | interest pages |
   | GET | `/corridors`, `/corridors/:slug` | corridor pages |
   | GET | `/search?q=` | search |
   | GET | `/me/reviews` | My reviews |
   | POST | `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/logout` | auth |
   | GET | `/auth/me` | session restore |
   | GET | `/me/saved`, `/me/stamps` | not wired yet — see the table below |

   Lists may come back bare (`[…]`) or wrapped (`{"items": […]}` / `{"data": …}`).
3. **Match the JSON.** The models accept the mock shape and common variants
   (`region`/`region_slug`, `lat`/`latitude`, `token`/`accessToken`, `{data: …}`
   wrappers). If a field is named differently, add it to the `alt:` list in that
   model's `fromJson`.
4. **Opening hours and review counts.** Place cards show Open/Closed, hours
   and "★ rating (count)" from `openTime`, `closeTime` (`"HH:mm"`, Cambodia
   time), `open24h` and `reviewCount`. The hours in `assets/mock` are
   **placeholders by place type**, because the website has none. Real values
   must come from the API.
5. **Sync user data.** Saved places and stamps are stored on the device today;
   the `TODO(api)` comments in `lib/state/collections_provider.dart` mark where to
   sync them with `/me/saved` and `/me/stamps`.
6. Run `flutter test`. `test/mock_data_test.dart` shows how to check a real
   response against the models.

## What the API still has to provide

Everything below is faked in the app today. Each one is marked `TODO(api)` in
the code — `grep -rn "TODO(api)" lib` lists them all.

| Area | Where | What is needed |
|---|---|---|
| Room prices | `data/models/destination.dart`, `assets/mock/rooms.json` | `priceFrom` and `currency` per stay, and the rooms themselves |
| Opening hours | `assets/mock/destinations.json` | real `openTime` / `closeTime` / `open24h` — the mock values are guesses by place type |
| Stay policies | `features/destination/place_view.dart` | check-in/out, cancellation, children, pets |
| Contact details | `assets/mock/destinations.json` | phone, email, website, Telegram per place |
| Corridor plans | `assets/mock/corridors.json` | the day-by-day itineraries are invented |
| Reviews | `/regions/:region/destinations/:slug/reviews`, `/me/reviews` | the seeded reviews in `assets/mock` (including `place_reviews.json`) are placeholders |
| Ratings and review counts | `assets/mock/destinations.json` | only 13 ratings came from the website; the rest, and every `reviewCount`, are generated placeholders |
| Place photos | `assets/mock/destinations.json` | each place has one real photo; the other four in its gallery are stock shots borrowed from the same interest and region |
| Profile | `state/auth_provider.dart` | `location` and `joinedOn` on the user, plus `PATCH /me` and `PATCH /me/password` |
| Saved, folders, stamps, badges | `state/collections_provider.dart` | `/me/saved`, `/me/folders`, `/me/stamps`, badge tiers and earned dates |
| Preferences | `state/settings_provider.dart` | store language/currency/unit/notifications on the account; a live USD→KHR rate (fixed at 4100 now) |
| Notifications | `features/profile/preference_pages.dart` | a push service behind the toggle |
| Review photos | `features/destination/review_screen.dart` | photo upload |
| Support details | `features/profile/help_support_screen.dart` | real support email, phone, website and social links |
| Terms & privacy | `features/profile/terms_screen.dart` | the final legal wording, and a Khmer translation by a person |

## Before release

- **Map tiles:** the public OpenStreetMap server is for development only. Set
  `tileUrl` in `lib/widgets/map_view.dart` to a paid tile provider.
- **Road routing:** corridor routes are snapped to real roads by the public
  OSRM demo server (`lib/core/network/routing_service.dart`), which has no
  uptime guarantee. Move to a hosted routing service.
- **Bundle ID:** change `com.example.amsTravel` (iOS) and
  `com.example.ams_travel` (Android) to your own.
- **Token storage:** move the session token to `flutter_secure_storage`.
- **App icon:** regenerate from `assets/icon/` with `dart run flutter_launcher_icons`.
