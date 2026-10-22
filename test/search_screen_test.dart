import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/search/filter_sheet.dart';
import 'package:ams_travel/features/search/search_screen.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Lets the fixture reads (real file I/O) and the debounce timers finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// The calls made to [path], newest last.
List<Map<String, dynamic>> _calls(FixtureAdapter adapter, String path) => [
  for (final r in adapter.requests)
    if (r.path == path) r.queryParameters,
];

Future<FixtureAdapter> _pump(
  WidgetTester tester, {
  Map<String, Object> prefsValues = const {},
  String? query,
  SearchFilters? filters,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final adapter = FixtureAdapter();
  final api = AmsApi(ApiClient(adapter: adapter));
  // A guest: the place cards' hearts read the saved list.
  final auth = await fakeAuth(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<AmsApi>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => SavedProvider(api, auth)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ],
      child: MaterialApp(
        home: SearchScreen(initialQuery: query, initialFilters: filters),
      ),
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
  });
  setUp(rootBundle.clear);

  testWidgets('before anything is typed: nearby, recent keywords and the corridors from the API', (tester) async {
    final adapter = await _pump(
      tester,
      prefsValues: {
        SearchScreen.recentKey: ['angkor'],
      },
    );

    expect(find.text('Explore by Nearby'), findsOneWidget);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('angkor'), findsOneWidget);

    // Under them, five destinations from across the Tourism Regions.
    expect(find.text('Tourism Regions'), findsOneWidget);
    final popular = _calls(adapter, '/popular');
    final regional = popular.singleWhere((q) => q['regionIds'] != null);
    expect('${regional['limit']}', '5');

    // Then popular destinations anywhere, less the ones already listed:
    // the fixture answers both calls alike, so nothing is left to show.
    expect(popular.where((q) => q['regionIds'] == null), hasLength(1));
    expect(find.text('Popular destinations'), findsNothing);

    // The page's own list, not the search field's or a row's.
    final page = find.ancestor(of: find.text('Explore by Nearby'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Recommend Corridors'), 300, scrollable: page);
    expect(find.text('Coastal Discovery'), findsOneWidget);
    expect(_calls(adapter, '/search').where((q) => q['type'] == 'CORRIDOR'), hasLength(1));
    // No hard-coded "popular" keywords any more.
    expect(find.text('royal palace'), findsNothing);
  });

  testWidgets('typing asks the server for suggestions and results', (tester) async {
    final adapter = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'ang');
    await _settle(tester);

    expect(_calls(adapter, '/search/suggest').last['q'], 'ang');
    final search = _calls(adapter, '/search').last;
    expect(search['q'], 'ang');
    expect(search['page'], 0);

    // Suggestions first (from /search/suggest), then the result rows.
    expect(find.text('Battambang'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsWidgets, reason: 'a province suggestion');
    expect(find.text('4 found'), findsOneWidget);
    expect(find.text('Bayon Temple'), findsOneWidget);
    expect(find.text('Explore by Nearby'), findsNothing);
  });

  testWidgets('filters chosen on Explore go to the server and show their results', (tester) async {
    const temples = 'b89409d1-29d6-4eb5-b573-3305cdab008e';
    const battambang = '8f0f4fed-2ccc-458d-9391-972f5870deca';
    final adapter = await _pump(
      tester,
      filters: const SearchFilters(provinceIds: {battambang}, categoryIds: {temples}),
    );

    // (The corridor list is read too, for the chips' names.)
    final search = _calls(adapter, '/search').lastWhere((q) => q['type'] != 'CORRIDOR');
    expect(search['provinceIds'], battambang);
    expect(search['categoryIds'], temples);
    expect(search.containsKey('q'), isFalse);
    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Explore by Nearby'), findsNothing);

    // Only what was picked shows over the results, each with a cross…
    expect(find.text('Battambang'), findsOneWidget);
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('All'), findsNothing, reason: 'no kind chips after Apply Filters');

    // …and the cross drops that pick.
    await tester.tap(
      find.descendant(of: find.widgetWithText(InputChip, 'Temples'), matching: find.byIcon(Icons.close_rounded)),
    );
    await _settle(tester);
    final again = _calls(adapter, '/search').lastWhere((q) => q['type'] != 'CORRIDOR');
    expect(again['provinceIds'], battambang);
    expect(again.containsKey('categoryIds'), isFalse);
  });

  testWidgets('the Filters sheet offers the API lists and sends what was picked', (tester) async {
    final adapter = await _pump(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await _settle(tester);

    // Tourism regions first, then categories and tags, all from the API.
    expect(find.text('Ancient Capitals & Khmer Civilization'), findsOneWidget);
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('UNESCO'), findsOneWidget);

    await tester.tap(find.text('Temples'));
    await _settle(tester);
    // The count on Apply is the server's.
    expect(_calls(adapter, '/search').last['size'], 1);
    expect(find.text('Apply Filters (4)'), findsOneWidget);

    await tester.tap(find.text('Provinces').first);
    await _settle(tester);
    await tester.tap(find.text('Battambang'));
    await _settle(tester);

    await tester.tap(find.text('Apply Filters (4)'));
    await _settle(tester);

    final search = _calls(adapter, '/search').lastWhere((q) => q['type'] != 'CORRIDOR');
    expect(search['categoryIds'], 'b89409d1-29d6-4eb5-b573-3305cdab008e');
    expect(search['provinceIds'], isNotNull);
    expect(search['size'], 20);
    expect(find.text('Bayon Temple'), findsOneWidget);
  });

  testWidgets('categories and tags follow the picked regions; corridors are a tab of their own', (tester) async {
    final adapter = await _pump(tester);
    // Wide enough for all four tabs along the top of the sheet.
    await tester.binding.setSurfaceSize(const Size(700, 1000));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await _settle(tester);

    // Every category and tag while no region is picked…
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('UNESCO'), findsOneWidget);

    // …then only the picked region's own (none of this one's are in the
    // fixture lists).
    await tester.tap(find.text('Northeastern Civilization'));
    await _settle(tester);
    expect(find.text('Temples'), findsNothing);
    expect(find.text('UNESCO'), findsNothing);

    // Another region brings its own back.
    await tester.tap(find.text('Ancient Capitals & Khmer Civilization'));
    await _settle(tester);
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('UNESCO'), findsOneWidget);

    // Corridors: picked ones go to the server as corridorIds.
    await tester.tap(find.text('Corridors'));
    await _settle(tester);
    // The sheet's chip, not the corridor row on the page behind it.
    await tester.tap(find.text('Coastal Discovery').last);
    await _settle(tester);
    await tester.tap(find.textContaining('Apply Filters'));
    await _settle(tester);
    expect(_calls(adapter, '/search').lastWhere((q) => q['type'] != 'CORRIDOR')['corridorIds'], isNotNull);
  });

  testWidgets('under the provinces: interest groups, then the chosen group\'s interests', (tester) async {
    final adapter = await _pump(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await _settle(tester);
    await tester.tap(find.text('Provinces').first);
    await _settle(tester);

    // Interests in place of Categories and Tags.
    expect(find.text('Categories'), findsNothing);
    expect(find.text('Tags'), findsNothing);
    expect(find.text('Interests'), findsWidgets);

    // A group sends its kind and all its interests…
    await tester.ensureVisible(find.text('Stays'));
    await tester.tap(find.text('Stays'));
    await _settle(tester);
    expect(find.text('Luxury Hotel'), findsOneWidget);
    var count = _calls(adapter, '/search').last;
    expect(count['type'], 'STAY');
    expect('${count['interestIds']}'.split(','), hasLength(5));

    // …until one of them is picked.
    await tester.ensureVisible(find.text('Homestay'));
    await tester.tap(find.text('Homestay'));
    await _settle(tester);
    count = _calls(adapter, '/search').last;
    expect('${count['interestIds']}'.split(','), hasLength(1));
  });

  test('filters compare by value and count only the sheet picks', () {
    const a = SearchFilters(kind: CardType.food, interestIds: {'x', 'y'});
    const b = SearchFilters(kind: CardType.food, interestIds: {'y', 'x'});
    expect(a, b);
    expect(a.count, 2);
    expect(const SearchFilters().isEmpty, isTrue);
    expect(const SearchFilters(kind: CardType.stay).isEmpty, isFalse);
    expect(a.cleared(), const SearchFilters(kind: CardType.food));
  });
}
