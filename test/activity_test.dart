import 'package:ams_travel/data/api/ams_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'destination_harness.dart';
import 'support/fake_api.dart';

const _cruise = '078303f6-baa1-4104-b549-927b6fd80716';

void main() {
  setUpDestinationTests();

  testWidgets('an activity from the API: its kind, interests, organiser, check-in and reviews', (tester) async {
    final h = await pumpAt(tester, '/activities/$_cruise');

    expect(find.text('Kampi Dolphin Sunset Cruise'), findsWidgets);
    expect(find.text('Cruise'), findsOneWidget, reason: 'its type is the interest of that name, shown once');
    expect(find.text('Wildlife'), findsOneWidget);
    // Every way to reach the organiser the API gives.
    expect(find.text('+855 72 555 3390'), findsOneWidget);
    expect(find.text('kampicruise.example.com'), findsOneWidget);
    expect(find.text('boats@kampicruise.example.com'), findsOneWidget);
    expect(find.text('@kampicruise'), findsOneWidget);
    expect(find.text('+855 10 555 339'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Scan to check in'), findsOneWidget);

    expect(h.calls, containsAll(['GET /activities/$_cruise', 'GET /media', 'GET /reviews', 'POST /popular/events']));
    final asked = {for (final r in h.adapter.requests) r.path: r.queryParameters};
    expect(asked['/search/cards']!['type'], 'ACTIVITY');
    expect(asked['/media']!['ownerType'], 'ACTIVITY');
    expect(asked['/reviews']!['targetType'], 'ACTIVITY');
    final browse = h.adapter.requests.firstWhere((r) => r.path == '/popular/events');
    expect((browse.data as Map)['targetType'], 'ACTIVITY');
  });

  testWidgets('signed in, opening an activity counts towards the Browser badge', (tester) async {
    final h = await pumpAt(tester, '/activities/$_cruise', signedIn: true);
    expect(h.calls, contains('PUT /badges/me/explorations/$_cruise'));
    expect(h.calls, isNot(contains('POST /popular/events')));
  });

  test('the Activities & Experiences chips search for activities', () async {
    final groups = await fakeAmsApi().interestGroups();
    final activities = groups.firstWhere((g) => g.name == InterestGroup.activities);
    expect(activities.cardType, CardType.activity);
    expect(activities.interests, hasLength(10));
  });
}
