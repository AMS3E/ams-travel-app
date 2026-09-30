import 'package:ams_travel/app.dart';
import 'package:ams_travel/data/repositories/auth_repository.dart';
import 'package:ams_travel/data/repositories/mock_travel_repository.dart';
import 'package:ams_travel/data/repositories/travel_repository.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/state/settings_provider.dart';
import 'package:ams_travel/state/travel_preferences.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return MultiProvider(
    providers: [
      Provider<TravelRepository>.value(value: MockTravelRepository()),
      ChangeNotifierProvider(create: (_) => AuthProvider(MockAuthRepository(), prefs)),
      ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
    ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
      ChangeNotifierProvider(create: (_) => SavedProvider(prefs)),
      ChangeNotifierProvider(create: (_) => StampsProvider(prefs)),
      ChangeNotifierProvider(create: (_) => TravelPreferences(prefs)),
    ],
    child: const AmsTravelApp(),
  );
}

/// Lets real I/O (asset loading) and fake timers (mock latency) both finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  // rootBundle caches asset loads across tests; a load cached inside an earlier
  // test's fake-async zone never resolves in the next test.
  setUp(rootBundle.clear);

  testWidgets('home loads and bottom navigation switches tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    await tester.pumpWidget(await _app());
    await _settle(tester);

    expect(find.text('Your location'), findsOneWidget);
    expect(find.text('Search destinations, places, food..'), findsOneWidget);
    expect(find.text('Explore by Tourism Region'), findsOneWidget);

    await tester.tap(find.text('Explore').last);
    await _settle(tester);
    expect(find.text('Explore Cambodia'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Keep the places you want to see in one list.'), findsOneWidget);

    // Language lives on the Preference page, behind the Language row.
    await tester.tap(find.text('Preference').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khmer (ភាសាខ្មែរ)').last);
    await tester.pumpAndSettle();
    expect(find.text('ភាសា'), findsWidgets, reason: 'the page is Khmer now');
  });

  testWidgets('home sections: Region → Popular → Corridors → Interest → Provinces', (tester) async {
    // A very tall screen so every home section is built at once.
    await tester.binding.setSurfaceSize(const Size(400, 7000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await _app());
    await _settle(tester);

    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    final order = [
      'Explore by Tourism Region',
      'Explore by Popular',
      'Explore by Corridors',
      'Explore by Interest',
      'Explore by Provinces',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i - 1]), lessThan(top(order[i])), reason: '${order[i - 1]} should be above ${order[i]}');
    }
    // The quick actions and the interest tiles are on the page.
    for (final label in ['Attraction', 'Stays', 'Food', 'Nature', 'Experiences']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Attraction Sites'), findsWidgets);
    expect(find.text('Stays'), findsWidgets);
  });
}
