import 'package:ams_travel/data/repositories/mock_travel_repository.dart';
import 'package:ams_travel/data/repositories/travel_repository.dart';
import 'package:ams_travel/features/map/map_screen.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:ams_travel/widgets/map_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
    AppMap.useTileCache = false;
    AppMap.useRoadRouting = false;
  });
  setUp(rootBundle.clear);

  testWidgets('layer chips put provinces, interests and corridors on the map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TravelRepository>.value(value: MockTravelRepository()),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
          ChangeNotifierProvider(create: (_) => SavedProvider(prefs)),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await _settle(tester);

    // Places to start with: all 199 pinned, one chip per list.
    expect(find.text('199'), findsOneWidget);
    for (final chip in ['Provinces', 'Interests', 'Corridors']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Regions'), findsNothing, reason: 'regions are not a map layer');

    // Provinces: twenty-five markers.
    await tester.tap(find.text('Provinces'));
    await _settle(tester);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Banteay Meanchey'), findsOneWidget, reason: 'legend starts at A');
    expect(find.text('Siem Reap'), findsNothing, reason: 'further along the scrolling legend');
    // Markers carry an icon now, so the legend is the way in. Choosing a
    // province puts the places inside it on the map.
    await tester.tap(find.text('Banteay Meanchey').first);
    await _settle(tester);
    expect(find.text('4'), findsWidgets, reason: 'its four places are pinned');
    await tester.tap(find.text('Provinces'));
    await _settle(tester);

    // Corridors: five routes, each marker naming its number of stops.
    await tester.tap(find.text('Corridors'));
    await _settle(tester);
    expect(find.text('1'), findsWidgets, reason: 'every route starts at stop 1');

    // Choosing one corridor leaves that route alone on the map, while the
    // legend still lists every corridor.
    await tester.tap(find.text('Khmer Civilization').first);
    await _settle(tester);
    expect(find.text('2'), findsOneWidget, reason: 'only the chosen route is drawn');
    expect(find.text('Khmer Civilization'), findsWidgets, reason: 'its card, and its legend chip');

    await tester.tap(find.byType(MapScreen)); // dismiss any open card
    await _settle(tester);

    // Interests: choosing one puts its places on the map.
    await tester.tap(find.text('Interests'));
    await _settle(tester);
    await tester.tap(find.text('Attraction Sites').first);
    await _settle(tester);
    expect(find.text('43'), findsWidgets, reason: 'the 43 attraction sites are pinned');
    await tester.tap(find.text('Interests'));
    await _settle(tester);
    await tester.tap(find.text('Corridors'));
    await _settle(tester);

    // Tapping the active chip goes back to every place.
    await tester.tap(find.text('Corridors'));
    await _settle(tester);
    expect(find.text('199'), findsOneWidget);
  });
}
