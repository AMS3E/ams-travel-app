import 'package:ams_travel/core/utils/html_text.dart';
import 'package:ams_travel/data/api/catalog.dart';
import 'package:ams_travel/features/region/region_places_screen.dart';
import 'package:ams_travel/features/region/regions_explore_screen.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';

import 'support/browse_pump.dart';
import 'support/fake_api.dart';

const _region = '56c67829-d5c8-427f-b599-0f1d63af2ee4';
const _temples = 'b89409d1-29d6-4eb5-b573-3305cdab008e';
const _unesco = 'aab060f1-ce03-41a0-8b1e-2c406321931e';

void main() {
  setUpBrowseTests();

  test('a region is Recommended by AMS Travel when staff mark it, and has a map picture once set', () {
    final plain = CatalogRegion.fromJson({'id': _region, 'name': 'x', 'code': 'X', 'kind': 'TOURISM', 'mapUrl': null});
    expect(plain.amsRecommended, isFalse);
    expect(plain.mapUrl, isEmpty);
    final marked = CatalogRegion.fromJson({
      'id': _region,
      'name': 'x',
      'code': 'X',
      'kind': 'TOURISM',
      'amsRecommended': true,
      'mapUrl': '/api/v1/media/files/general/map.jpg',
    });
    expect(marked.amsRecommended, isTrue);
    expect(marked.mapUrl, endsWith('/api/v1/media/files/general/map.jpg'));
  });

  testWidgets('Regions list: each tourism region with three of its places', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const RegionsExploreScreen(), adapter: adapter);

    expect(lastQuery(adapter, '/regions')['kind'], 'TOURISM');
    final searches = requestsTo(adapter, '/search');
    expect(searches, hasLength(3), reason: 'one search per region');
    expect({for (final r in searches) r.queryParameters['regionId']}, hasLength(3));
    expect(searches.every((r) => r.queryParameters['size'] == 3), isTrue);

    expect(find.text('Ancient Capitals & Khmer Civilization'), findsOneWidget);
    expect(find.text('Angkor Wat'), findsWidgets);
  });

  testWidgets('Region page: overview from HTML, chips filter on the server', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const RegionPlacesScreen(id: _region), adapter: adapter);

    expect(find.text('Ancient Capitals & Khmer Civilization'), findsOneWidget);
    expect(find.textContaining('<'), findsNothing, reason: 'the HTML overview reads as text');
    expect(find.textContaining('Khmer empire'), findsOneWidget);

    // Staff marked the region, and set its map picture.
    expect(find.text('Recommend by AMS Travel'), findsOneWidget);
    expect(find.text('Historical Map'), findsOneWidget);
    expect(find.text('Map'), findsNothing);

    // The first page of the region's places.
    final first = lastQuery(adapter, '/search');
    expect(first['regionId'], _region);
    expect(first['size'], 20);

    // The chips are the region's categories and tags by name.
    expect(find.text('Temples'), findsWidgets);
    expect(find.text('UNESCO'), findsOneWidget);
    // The page's own scroll, not the card grid inside it.
    await tester.scrollUntilVisible(find.text('Angkor Wat'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Temples, Ancient Cities'), findsNothing, reason: 'region cards leave the categories out');

    await tester.ensureVisible(find.text('UNESCO'));
    await tester.tap(find.text('UNESCO'));
    await settle(tester);
    var q = lastQuery(adapter, '/search');
    expect(q['regionId'], _region);
    expect(q['tagIds'], _unesco);
    expect(q['categoryIds'], isNull);

    await tester.ensureVisible(find.text('Temples').first);
    await tester.tap(find.text('Temples').first);
    await settle(tester);
    q = lastQuery(adapter, '/search');
    expect(q['categoryIds'], _temples);
    expect(q['tagIds'], _unesco);
    expect(find.text('Reset'), findsOneWidget);
  });

  test('htmlToText keeps paragraphs and bullets and decodes entities', () {
    expect(
      htmlToText('<p>Royal <strong>capitals</strong></p><ul><li>Roads &amp; bridges</li><li>Temples</li></ul>'),
      'Royal capitals\n\n• Roads & bridges\n• Temples',
    );
    expect(htmlToText('Plain text,<br/>two lines&nbsp;here'), 'Plain text,\ntwo lines here');
    expect(htmlToText(null), '');
  });
}
