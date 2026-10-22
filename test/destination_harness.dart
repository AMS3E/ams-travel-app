import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/destination/activity_screen.dart';
import 'package:ams_travel/features/destination/destination_screen.dart';
import 'package:ams_travel/features/destination/food_screen.dart';
import 'package:ams_travel/features/destination/review_screen.dart';
import 'package:ams_travel/features/destination/reviews_screen.dart';
import 'package:ams_travel/features/destination/room_screen.dart';
import 'package:ams_travel/features/destination/rooms_screen.dart';
import 'package:ams_travel/features/destination/stay_screen.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:ams_travel/widgets/map_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Shared set-up for the destination, stay, food and review tests: the
/// screens of that area behind a router, answering from the fixtures.

const angkorWat = '6cd2c24d-a1c1-4bbe-9833-31d30e763ee6';
const riversideLodge = '7c1e2d3f-4a5b-4c6d-8e9f-0a1b2c3d4e51';
const deluxeKing = '7c1e2d3f-4a5b-4c6d-8e9f-0a1b2c3d4e52';
const banteayKitchen = '8d2f3e4a-5b6c-4d7e-9f0a-1b2c3d4e5f61';

/// The fixtures, except for the paths in [overrides] (path → JSON body).
class OverrideAdapter implements HttpClientAdapter {
  OverrideAdapter([this.overrides = const {}]);
  final Map<String, String> overrides;
  final fixtures = FixtureAdapter();

  List<RequestOptions> get requests => fixtures.requests;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) {
    final key = '${o.method.toUpperCase()} ${o.path}';
    final over = overrides[key] ?? (o.method.toUpperCase() == 'GET' ? overrides[o.path] : null);
    if (over != null) {
      fixtures.requests.add(o);
      return Future.value(
        ResponseBody.fromString(
          over,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
    }
    return fixtures.fetch(o, body, cancel);
  }

  @override
  void close({bool force = false}) {}
}

void setUpDestinationTests() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
    AppMap.useTileCache = false;
  });
  setUp(rootBundle.clear);
}

/// Lets the fixture answers arrive.
Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class Harness {
  Harness(this.adapter, this.prefs, this.router);
  final OverrideAdapter adapter;
  final SharedPreferences prefs;
  final GoRouter router;

  /// The paths asked of the server, with their method: "GET /stays/x".
  List<String> get calls => [for (final r in adapter.requests) '${r.method.toUpperCase()} ${r.path}'];
}

/// Opens [location] in a router holding this area's screens.
Future<Harness> pumpAt(
  WidgetTester tester,
  String location, {
  bool signedIn = false,
  Map<String, String> overrides = const {},
  Future<List<String>> Function()? picker,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final adapter = OverrideAdapter(overrides);
  final client = ApiClient(adapter: adapter);
  final api = AmsApi(client);
  final auth = await fakeAuth(prefs, signedIn: signedIn);
  client.tokens = auth;

  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/map',
        builder: (_, _) => const Scaffold(body: Text('map')),
      ),
      GoRoute(
        path: '/places/:id',
        builder: (_, s) => DestinationScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stays/:stay',
        builder: (_, s) => StayScreen(id: s.pathParameters['stay']!),
      ),
      GoRoute(
        path: '/stays/:stay/rooms',
        builder: (_, s) => RoomsScreen(stayId: s.pathParameters['stay']!),
      ),
      GoRoute(
        path: '/stays/:stay/rooms/:room',
        builder: (_, s) => RoomScreen(stayId: s.pathParameters['stay']!, roomId: s.pathParameters['room']!),
      ),
      GoRoute(
        path: '/foods/:food',
        builder: (_, s) => FoodScreen(id: s.pathParameters['food']!),
      ),
      GoRoute(
        path: '/activities/:activity',
        builder: (_, s) => ActivityScreen(id: s.pathParameters['activity']!),
      ),
      GoRoute(
        path: '/check-in',
        builder: (_, _) => const Scaffold(body: Text('scanner')),
      ),
      GoRoute(
        path: '/reviews/:type/:id',
        builder: (_, s) =>
            ReviewsScreen(type: CardType.values.byName(s.pathParameters['type']!), id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reviews/:type/:id/new',
        builder: (_, s) => ReviewScreen(
          type: CardType.values.byName(s.pathParameters['type']!),
          id: s.pathParameters['id']!,
          picker: picker,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<AmsApi>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => SavedProvider(api, auth)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await settle(tester);
  return Harness(adapter, prefs, router);
}
