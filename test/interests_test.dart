import 'package:ams_travel/data/api/catalog.dart';
import 'package:ams_travel/data/models/json_utils.dart';
import 'package:ams_travel/features/interest/interest_explore_screen.dart';
import 'package:ams_travel/features/interest/interest_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/browse_pump.dart';
import 'support/fake_api.dart';

const _historicalSites = '1c6a8452-1344-4d4e-a071-ceb684824181';

void main() {
  setUpBrowseTests();

  test('an interest has a picture once staff set one', () {
    Json interest(String? cover) => {'id': _historicalSites, 'name': 'x', 'slug': 'x', 'groupName': 'Water', 'coverUrl': cover};
    expect(CatalogInterest.fromJson(interest(null)).coverUrl, isEmpty);
    expect(CatalogInterest.fromJson(interest('/api/v1/media/files/general/x.jpg')).coverUrl, endsWith('/general/x.jpg'));
  });

  testWidgets('Interest page opens on its group and asks the server for its interests', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const InterestScreen(group: 'attraction-sites'), adapter: adapter);

    var q = lastQuery(adapter, '/search');
    expect((q['interestIds'] as String).split(','), hasLength(4), reason: 'the whole Attraction Sites group');
    expect(q['type'], isNull);
    // In the grid, and in the Recommend panel: the fixture answers the seal
    // filter with the same places.
    expect(find.text('Angkor Wat'), findsWidgets);
    expect(find.text('Temples, Ancient Cities'), findsWidgets, reason: 'the category line of the card');
    final sealed = adapter.requests.where((r) => r.path == '/search' && r.queryParameters['travelerRecommended'] == true);
    expect(sealed, isNotEmpty, reason: 'the Recommend panel asks the server for the seal holders');

    // A finer pick in the second row narrows the call to that interest.
    await tester.tap(find.text('Historical Sites'));
    await settle(tester);
    q = lastQuery(adapter, '/search');
    expect(q['interestIds'], _historicalSites);

    // The corridors group lists corridors, by type.
    await tester.scrollUntilVisible(find.text('Tourism Corridors'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Tourism Corridors'));
    await settle(tester);
    q = lastQuery(adapter, '/search');
    expect(q['type'], 'CORRIDOR');
    expect((q['interestIds'] as String).split(','), hasLength(5));
    expect(find.text('Coastal Discovery'), findsWidgets);
  });

  testWidgets('A group slug further along the row opens that group', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const InterestScreen(group: 'tourism-corridors'), adapter: adapter);
    expect(lastQuery(adapter, '/search')['type'], 'CORRIDOR');
    expect(find.text('Khmer Civilization'), findsWidgets);
  });

  testWidgets('Interests explore starts on the first group', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const InterestExploreScreen(), adapter: adapter);
    expect(find.text('Explore interest'), findsOneWidget);
    expect((lastQuery(adapter, '/search')['interestIds'] as String).split(','), hasLength(4));
    expect(find.text('Angkor Wat'), findsWidgets);
  });
}
