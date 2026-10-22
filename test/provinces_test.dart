import 'package:ams_travel/features/province/province_places_screen.dart';
import 'package:ams_travel/features/province/province_screen.dart';
import 'package:ams_travel/features/province/provinces_explore_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/browse_pump.dart';
import 'support/fake_api.dart';

const _battambang = '8f0f4fed-2ccc-458d-9391-972f5870deca';

void main() {
  setUpBrowseTests();

  testWidgets('Provinces list: one by-province call for the page; chips send interestIds and type', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const ProvincesExploreScreen(), adapter: adapter);

    expect(find.text('Battambang'), findsOneWidget);
    var calls = requestsTo(adapter, '/search/by-province');
    expect(calls, hasLength(1));
    expect(calls.single.queryParameters['perProvince'], 8);
    expect(calls.single.queryParameters['interestIds'], isNull);
    expect(requestsTo(adapter, '/search'), isEmpty, reason: 'no call per row');

    adapter.requests.clear();
    await tester.tap(find.text('Attraction Sites'));
    await settle(tester);
    calls = requestsTo(adapter, '/search/by-province');
    expect(calls, hasLength(1));
    final ids = (calls.single.queryParameters['interestIds'] as String).split(',');
    expect(ids, hasLength(4), reason: 'the whole Attraction Sites group');
    expect(calls.single.queryParameters['type'], isNull);
  });

  testWidgets('Places in a province: kind chips send the type, empty answers say so', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const ProvincePlacesScreen(id: _battambang), adapter: adapter);

    expect(find.text('Explore more in Battambang'), findsOneWidget);
    expect(lastQuery(adapter, '/search')['provinceId'], _battambang);
    expect(find.text('Angkor Wat'), findsOneWidget);

    await tester.tap(find.text('Stays'));
    await settle(tester);
    final q = lastQuery(adapter, '/search');
    expect(q['provinceId'], _battambang);
    expect(q['type'], 'STAY');
    expect(q['interestIds'], isNotNull);
    expect(find.text('Nothing matches those filters'), findsOneWidget);
  });

  testWidgets('Province page: its own place count, the map and the cards', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const ProvinceScreen(id: _battambang), adapter: adapter);

    expect(find.text('Battambang'), findsWidgets);
    expect(lastQuery(adapter, '/search')['provinceId'], _battambang);
    expect(find.text('4'), findsOneWidget, reason: "the province's placeCount");
    await tester.scrollUntilVisible(find.text('Angkor Wat'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Angkor Wat'), findsOneWidget);
  });
}
