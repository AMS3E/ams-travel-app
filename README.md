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

| Tab / page | Route | Website equivalent |
|---|---|---|
| Home | `/` | `/` — hero, search, stats, regions, recommended, popular now, corridors, interests, provinces, why AMS, reviews, plan-your-route form |
| Explore | `/explore?tab=regions\|interests\|provinces\|corridors` | `/explore`, `/explore/interests`, `/explore/provinces`, `/explore/corridors` |
| Map | `/map?place=region/slug` | `/map` — every place, filter by region or saved |
| Saved | `/saved` | `/saved` — places, regions, corridors, stamps |
| Profile | `/profile` | Log in / language toggle |
| Region | `/regions/:region` | about, highlights timeline, category chips, filters (province, century, king…), cards/map toggle |
| Destination | `/regions/:region/:slug` | badges, save, share, collect stamp, Google Maps, at a glance, nearby, reviews |
| Story | `/regions/:region/stories/:slug` | historical coverage steps |
| Province | `/provinces/:slug` | map + places grouped by region |
| Interest | `/interests/:slug` | places for one interest across regions |
| Corridor | `/corridors/:slug` | route map, stops, places near each stop |
| Search | `/search?q=` | "Search everything" |
| Auth | `/login`, `/register`, `/forgot-password` | same validation rules as the website |

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
  state/                       ← auth session, saved list, stamps, language (Provider)
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
2. **Match the routes.** Edit the paths in `ApiEndpoints` (same file).
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

## Before release

- **Map tiles:** the public OpenStreetMap server is for development only. Set
  `tileUrl` in `lib/widgets/map_view.dart` to a paid tile provider.
- **Bundle ID:** change `com.example.amsTravel` (iOS) and
  `com.example.ams_travel` (Android) to your own.
- **Token storage:** move the session token to `flutter_secure_storage`.
- **App icon:** regenerate from `assets/icon/` with `dart run flutter_launcher_icons`.
