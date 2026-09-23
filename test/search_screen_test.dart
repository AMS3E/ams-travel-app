import 'dart:convert';
import 'dart:io';

import 'package:ams_travel/data/repositories/mock_travel_repository.dart';
import 'package:ams_travel/data/repositories/travel_repository.dart';
import 'package:ams_travel/features/search/filter_sheet.dart';
import 'package:ams_travel/features/search/search_screen.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search results arrive after real asset I/O plus simulated latency, so let
/// both real and fake time advance until [finder] shows up (max ~3 s).
/// Lets the last search's loads finish, so no timer is left pending.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('Interests chip shows the interest suggestions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>.value(value: prefs),
          Provider<TravelRepository>.value(value: MockTravelRepository()),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ],
        child: const MaterialApp(home: SearchScreen(initialQuery: '')),
      ),
    );

    // "All" shows the browse suggestions: nearby, recent and popular terms.
    await _pumpUntil(tester, find.text('Explore by Nearby'));
    expect(find.text('Explore by Nearby'), findsOneWidget);
    expect(find.text('Recent & Popular'), findsOneWidget);
    expect(find.text('royal palace'), findsOneWidget);
    expect(find.text('Attraction Sites'), findsNothing);

    await tester.tap(find.text('Interests'));
    await tester.pump();

    for (final label in [
      'Attraction Sites',
      'Stays',
      'Food',
      'Water',
      'Activities & Experiences',
      'Tourism Corridors',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Explore by Nearby'), findsNothing, reason: 'the browse suggestions give way to the list');

    await tester.tap(find.text('Regions'));
    await tester.pump();
    for (final label in [
      'Ancient Capitals & Khmer Civilization Region',
      'Northeastern Civilization',
      'Mekong & Tonle Sap Civilization',
      'Mountain & Waterfall Region',
      'Coastal & Island Region',
      'Urban Lifestyle & Nightlife',
      'Khmer Culinary Region',
      'Eco-Community Tourism',
      'Luxury Tourism',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // Tapping a region suggestion finds that region.
    await tester.tap(find.text('Ancient Capitals & Khmer Civilization Region'));
    await _pumpUntil(tester, find.text('Ancient Capitals & Khmer Civilization'));
    expect(find.text('Ancient Capitals & Khmer Civilization'), findsOneWidget);
    expect(find.text('No matches'), findsNothing);
    await _drain(tester);
  });

  testWidgets('Provinces chip shows all 25 provinces', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>.value(value: prefs),
          Provider<TravelRepository>.value(value: MockTravelRepository()),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ],
        child: const MaterialApp(home: SearchScreen(initialQuery: '')),
      ),
    );

    await _pumpUntil(tester, find.text('Explore by Nearby'));
    await tester.tap(find.text('Provinces'));
    await tester.pump();

    // Every province in the data appears as a suggestion, spelled the same.
    final provinces = (jsonDecode(File('assets/mock/provinces.json').readAsStringSync()) as List)
        .map((p) => (p as Map)['name'] as String)
        .toList();
    expect(provinces, hasLength(25));
    for (final name in provinces) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Corridors chip shows the five corridors and tapping one finds it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>.value(value: prefs),
          Provider<TravelRepository>.value(value: MockTravelRepository()),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ],
        child: const MaterialApp(home: SearchScreen(initialQuery: '')),
      ),
    );

    await tester.tap(find.text('Corridors'));
    await tester.pump();

    const corridors = [
      'Khmer Civilization',
      'Mekong Civilization',
      'Coastal Discovery',
      'Mountain Adventure',
      'Khmer Culinary',
    ];
    for (final name in corridors) {
      expect(find.text(name), findsOneWidget, reason: name);
    }

    await tester.tap(find.text('Mekong Civilization'));
    await _pumpUntil(tester, find.text('6 – 9 days'));
    expect(find.text('6 – 9 days'), findsOneWidget);
    expect(find.text('No matches'), findsNothing);
    await _drain(tester);
  });

  testWidgets('filters chosen before opening show their results right away', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>.value(value: prefs),
          Provider<TravelRepository>.value(value: MockTravelRepository()),
          ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ],
        child: const MaterialApp(
          // What Home's filter button hands over.
          home: SearchScreen(initialFilters: SearchFilters(categories: {'Temples'})),
        ),
      ),
    );

    await _pumpUntil(tester, find.text('Angkor Wat'));
    expect(find.text('Angkor Wat'), findsWidgets, reason: 'temples, not the browse suggestions');
    expect(find.text('Explore by Nearby'), findsNothing);
    await _drain(tester);
  });
}
