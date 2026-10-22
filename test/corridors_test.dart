import 'package:ams_travel/features/corridor/corridor_screen.dart';
import 'package:ams_travel/features/corridor/corridors_explore_screen.dart';
import 'package:ams_travel/widgets/map_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/browse_pump.dart';
import 'support/fake_api.dart';

const _corridor = 'ef52e705-d9ef-4412-a9c4-b14a4b9bd11a';

void main() {
  setUpBrowseTests();

  testWidgets('Corridors list is the CORRIDOR search', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const CorridorsExploreScreen(), adapter: adapter);
    expect(lastQuery(adapter, '/search')['type'], 'CORRIDOR');
    expect(find.text('Coastal Discovery'), findsOneWidget);
    expect(find.text('Khmer Civilization'), findsOneWidget);
  });

  testWidgets('Corridor page: itinerary, chips, route line from the polyline, reviews', (tester) async {
    final adapter = FixtureAdapter();
    await pumpBrowse(tester, const CorridorScreen(id: _corridor), adapter: adapter, size: const Size(400, 3200));

    expect(requestsTo(adapter, '/corridors/$_corridor/itinerary'), hasLength(1));
    final card = lastQuery(adapter, '/search/cards');
    expect(card['ids'], _corridor);
    expect(card['type'], 'CORRIDOR');
    final reviews = lastQuery(adapter, '/reviews');
    expect(reviews['targetType'], 'CORRIDOR');
    expect(reviews['targetId'], _corridor);
    final media = lastQuery(adapter, '/media');
    expect(media['ownerType'], 'CORRIDOR', reason: 'the corridor gallery');
    expect(media['ownerId'], _corridor);

    expect(find.text('Khmer Civilization'), findsWidgets);
    // "What you expect" is the corridor's own labels, in order, as text.
    expect(find.text('What you expect'), findsOneWidget);
    for (final label in ['Sunrise', 'Photography', 'Historic Site']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('4 stops'), findsOneWidget);
    expect(find.text('Recommend by Traveler'), findsNothing, reason: 'the seal is design filler on a corridor');

    // Route overview: the stops in order, with the place's words when the
    // stop has none.
    expect(find.text('Angkor Wat'), findsWidgets);
    expect(find.text('Royal Palace'), findsWidgets);
    expect(find.textContaining("Cambodia's national symbol"), findsOneWidget);

    // The map draws the server's encoded route, and a pin per stop.
    final map = tester.widget<AppMap>(find.byType(AppMap));
    expect(map.routes.single.points.length, greaterThan(100));
    expect(map.pins, hasLength(4));

    expect(find.textContaining('Three capitals in three days'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
  });
}
