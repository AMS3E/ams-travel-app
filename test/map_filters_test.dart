import 'dart:convert';
import 'dart:io';

import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/map/map_screen.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:ams_travel/widgets/map_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show PolylineLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

const _khmerCivilization = 'ef52e705-d9ef-4412-a9c4-b14a4b9bd11a';
const _angkorWat = '6cd2c24d-a1c1-4bbe-9833-31d30e763ee6';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// How many cards with a pin a saved `/search` answer holds.
int _pinsIn(String fixture) {
  final body = jsonDecode(File('${FixtureAdapter.dir}/$fixture').readAsStringSync()) as Map;
  return (body['content'] as List).where((c) => (c as Map)['latitude'] != null).length;
}

/// The map with a guest session, answering from the saved fixtures. Returns
/// the adapter, to check what was asked of the server.
Future<FixtureAdapter> _pumpMap(WidgetTester tester, {String? focusId, String? corridorId}) async {
  await tester.binding.setSurfaceSize(const Size(400, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final adapter = FixtureAdapter();
  final api = AmsApi(ApiClient(adapter: adapter));
  final auth = await fakeAuth(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AmsApi>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => SavedProvider(api, auth)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ],
      child: MaterialApp(home: MapScreen(focusId: focusId, corridorId: corridorId)),
    ),
  );
  await _settle(tester);
  return adapter;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
    AppMap.useTileCache = false;
  });
  setUp(rootBundle.clear);

  testWidgets('without location the map offers to allow it, and chips ask the server', (tester) async {
    final adapter = await _pumpMap(tester);

    // Tests have no location plugin: no pins, and the offer to allow it.
    expect(find.text('Turn on location to see the places around you.'), findsOneWidget);
    expect(find.text('Allow location access'), findsOneWidget);
    expect(find.text('0'), findsOneWidget, reason: 'nothing pinned');
    expect(adapter.requests.where((r) => r.path == '/destinations/nearby'), isEmpty);
    for (final chip in ['Regions', 'Provinces', 'Interests', 'Corridors']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }

    // A province chip pins that province's places, from GET /search.
    await tester.tap(find.text('Provinces'));
    await _settle(tester);
    expect(find.text('Banteay Meanchey'), findsOneWidget, reason: 'the province row');
    await tester.tap(find.text('Banteay Meanchey'));
    await _settle(tester);
    final search = adapter.requests.lastWhere((r) => r.path == '/search');
    expect(search.queryParameters['provinceId'], '105c742e-87c5-4bcb-a7d7-9187581fd3fd');
    expect(search.queryParameters['size'], 100);
    expect(find.text('${_pinsIn('search.json')}'), findsOneWidget, reason: 'every card with a pin');

    // Interests: the first group's interests go to the server.
    await tester.tap(find.text('Interests'));
    await _settle(tester);
    final byInterest = adapter.requests.lastWhere((r) => r.path == '/search');
    expect(byInterest.queryParameters['interestIds'], isNotEmpty);
    expect(byInterest.queryParameters['provinceId'], isNull);

    // Corridors: nothing drawn until one is picked; then its itinerary.
    await tester.tap(find.text('Corridors'));
    await _settle(tester);
    expect(find.text('Pick a corridor to see its stops.'), findsOneWidget);
    await tester.tap(find.text('Khmer Civilization'));
    await _settle(tester);
    expect(adapter.requests.last.path, '/corridors/$_khmerCivilization/itinerary');
    for (final stop in ['1', '2', '3']) {
      expect(find.text(stop), findsOneWidget, reason: 'stop $stop');
    }
    expect(find.text('4'), findsNWidgets(2), reason: 'the last stop, and the pin count');
    expect(find.text('Khmer Civilization'), findsWidgets, reason: 'its chip and its card');
    expect(find.text('3 days  ·  4 stops'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget, reason: 'the road line from the API');

    // Tapping the active chip goes back to the places around the traveller.
    await tester.tap(find.text('Corridors'));
    await _settle(tester);
    expect(find.text('Turn on location to see the places around you.'), findsOneWidget);
  });

  testWidgets('a place opened from its page shows its pin and card', (tester) async {
    final adapter = await _pumpMap(tester, focusId: _angkorWat);
    final cards = adapter.requests.lastWhere((r) => r.path == '/search/cards');
    expect(cards.queryParameters['ids'], _angkorWat);
    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Siem Reap'), findsOneWidget, reason: 'its province');
    expect(find.text('Show route'), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: 'one pin');
  });

  testWidgets('a corridor link opens on its route', (tester) async {
    final adapter = await _pumpMap(tester, corridorId: _khmerCivilization);
    expect(adapter.requests.any((r) => r.path == '/corridors/$_khmerCivilization/itinerary'), isTrue);
    expect(find.text('3 days  ·  4 stops'), findsOneWidget);
  });

  testWidgets('saved places on the map need an account', (tester) async {
    final adapter = await _pumpMap(tester);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await _settle(tester);
    expect(find.text('Log in to see your saved places on the map.'), findsOneWidget);
    expect(adapter.requests.where((r) => r.path == '/favorites'), isEmpty);
  });
}
