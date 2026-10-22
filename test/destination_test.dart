import 'dart:convert';
import 'dart:io';

import 'package:ams_travel/core/utils/html_text.dart';
import 'package:ams_travel/features/destination/browse_record.dart';
import 'package:ams_travel/features/destination/place_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'destination_harness.dart';
import 'support/fake_api.dart';

const _emptyPage = '{"content":[],"page":{"size":6,"number":0,"totalElements":0,"totalPages":0}}';

void main() {
  setUpDestinationTests();

  testWidgets('a guest sees the attraction from the API and records a browse', (tester) async {
    final h = await pumpAt(tester, '/places/$angkorWat');

    expect(find.text('Angkor Wat'), findsWidgets);
    // Categories by name from GET /categories.
    expect(find.text('Temples'), findsOneWidget);
    expect(find.text('Ancient Cities'), findsOneWidget);
    expect(find.textContaining("The world's largest religious monument"), findsOneWidget);
    // Nobody has rated it: no score, no Traveler seal.
    expect(find.text('No reviews yet'), findsWidgets);
    expect(find.text('Recommend by Traveler'), findsNothing);
    expect(find.text('How to get there'), findsOneWidget);
    expect(find.text('Angkor Wat, Siem Reap'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('I am here'), findsNothing, reason: 'no GPS-only check-in any more');
    expect(find.text('Scan to check in'), findsOneWidget, reason: 'check-in is by the code posted on site');
    // What Travelers Say, from GET /reviews.
    expect(find.text('Dara Chan'), findsOneWidget);
    // Stays and food near it, with their own fields.
    expect(find.text('Stays nearby'), findsOneWidget);
    expect(find.text('Angkor Riverside Lodge'), findsOneWidget);
    expect(find.text('Food nearby'), findsOneWidget);
    expect(find.text('Banteay Kitchen'), findsOneWidget);
    expect(find.text('Activities nearby'), findsOneWidget);
    expect(find.text('Kampi Dolphin Sunset Cruise'), findsOneWidget);

    expect(
      h.calls,
      containsAll([
        'GET /destinations/$angkorWat',
        'GET /search/cards',
        'GET /media',
        'GET /categories',
        'GET /reviews',
        'GET /search',
        'POST /popular/events',
      ]),
    );
    final browse = h.adapter.requests.firstWhere((r) => r.path == '/popular/events');
    final session = h.prefs.getString(browseSessionKey);
    expect(session, isNotNull);
    expect(browse.data, {'targetType': 'DESTINATION', 'targetId': angkorWat, 'eventType': 'VIEW', 'sessionId': session});
    expect(h.calls.where((c) => c.startsWith('PUT /badges')), isEmpty);
    // Attractions, stays and food near it are cards from the server,
    // nearest first; the attractions within a radius, each with its distance.
    expect(h.calls, isNot(contains('GET /destinations/nearby')));
    final near = h.adapter.requests.where((r) => r.path == '/search' && r.queryParameters['near'] != null).toList();
    expect({for (final r in near) r.queryParameters['type']}, {'DESTINATION', 'STAY', 'FOOD', 'ACTIVITY'});
    expect(near.every((r) => r.queryParameters['near'] == angkorWat), isTrue);
    expect(near.firstWhere((r) => r.queryParameters['type'] == 'DESTINATION').queryParameters['radiusKm'], 5);
    expect(find.text('Recommend nearby'), findsOneWidget);
    expect(find.text('Bayon Temple'), findsOneWidget);
    expect(find.text('1.7 km'), findsOneWidget);
  });

  testWidgets('signed in, opening the page counts towards the Browser badge', (tester) async {
    final h = await pumpAt(tester, '/places/$angkorWat', signedIn: true);
    expect(h.calls, contains('PUT /badges/me/explorations/$angkorWat'));
    expect(h.calls, isNot(contains('POST /popular/events')));
  });

  testWidgets('an empty server: no reviews, no rows nearby, HTML made readable', (tester) async {
    final place = jsonDecode(File('${FixtureAdapter.dir}/destinations_$angkorWat.json').readAsStringSync()) as Map;
    place['description'] = '<p>Built for Vishnu &amp; later Buddhist.</p><ul><li>Moat</li><li>Causeway</li></ul>';
    place['slogan'] = 'Heaven on earth';
    place['sloganBy'] = 'A visitor';
    await pumpAt(
      tester,
      '/places/$angkorWat',
      overrides: {
        '/destinations/$angkorWat': jsonEncode(place),
        '/reviews': _emptyPage,
        '/search': _emptyPage,
      },
    );

    expect(find.text('Be the first to rate it.'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text('Stays nearby'), findsNothing);
    expect(find.text('Food nearby'), findsNothing);
    expect(find.text('"Heaven on earth"'), findsOneWidget);
    expect(find.text('— A visitor'), findsOneWidget);
    // The description folds; "Read more" shows all of it.
    await tester.ensureVisible(find.textContaining('Read\u00A0more'));
    await tester.tap(find.textContaining('Read\u00A0more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Built for Vishnu & later Buddhist.'), findsOneWidget);
    expect(find.textContaining('• Moat'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
  });

  test('plain text from the CMS HTML', () {
    expect(htmlToText('<p>A&nbsp;&amp;&nbsp;B</p><p>C<br/>D</p>'), 'A & B\n\nC\nD');
    expect(htmlToText(null), '');
    expect(htmlToText('Just words'), 'Just words');
  });

  test('money is shown in the currency the API gives, as one total', () {
    expect(money(300, 'USD'), r'US$300');
    expect(money(12.5, 'USD'), r'US$12.50');
    expect(money(120000, 'KHR'), '120,000 ៛');
  });
}
