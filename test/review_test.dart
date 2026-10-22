import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ams_travel/widgets/common.dart';

import 'destination_harness.dart';

String _review(int i) => jsonEncode({
  'id': 'r$i',
  'userId': 'u$i',
  'authorName': 'Traveller $i',
  'authorAvatarUrl': null,
  'targetType': 'DESTINATION',
  'targetId': angkorWat,
  'rating': 4,
  'title': 'Visit $i',
  'content': 'Words about visit $i.',
  'visitType': 'FAMILY',
  'visitedOn': '2026-08',
  'status': 'PUBLISHED',
  'photos': [],
  'createdAt': '2026-09-01T09:00:00Z',
});

void main() {
  setUpDestinationTests();

  testWidgets('all reviews: author, visit month and kind, title, words; no Helpful or Report', (tester) async {
    final h = await pumpAt(tester, '/reviews/destination/$angkorWat');

    expect(find.text('Dara Chan'), findsOneWidget);
    expect(find.text('Three capitals in three days'), findsOneWidget);
    expect(find.textContaining('September 2026  ·  Friends'), findsOneWidget);
    expect(find.text('All (1)'), findsOneWidget);
    // Helpful votes and reporting: parked 2026-10-14 (R-043, R-044).
    expect(find.byTooltip('Helpful'), findsNothing);
    expect(find.text('Report review'), findsNothing);
    final call = h.adapter.requests.firstWhere((r) => r.path == '/reviews');
    expect(call.queryParameters, containsPair('targetType', 'DESTINATION'));
    expect(call.queryParameters, containsPair('targetId', angkorWat));
    expect(call.queryParameters, containsPair('page', 0));
  });

  testWidgets('no reviews yet, and a guest is asked to log in to write one', (tester) async {
    final h = await pumpAt(
      tester,
      '/reviews/food/$banteayKitchen',
      overrides: {'/reviews': '{"content":[],"page":{"size":20,"number":0,"totalElements":0,"totalPages":0}}'},
    );
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    await tester.tap(find.text('Write a review'));
    await tester.pump();
    expect(find.text('Log in to write a review'), findsOneWidget);
    expect(h.router.state.uri.path, '/reviews/food/$banteayKitchen');
  });

  testWidgets('scrolling to the end asks for the next page', (tester) async {
    final page =
        '{"content":[${List.generate(20, _review).join(',')}],'
        '"page":{"size":20,"number":0,"totalElements":40,"totalPages":2}}';
    final h = await pumpAt(tester, '/reviews/destination/$angkorWat', overrides: {'/reviews': page});
    expect(find.text('All (40)'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await settle(tester);
    final pages = h.adapter.requests.where((r) => r.path == '/reviews').map((r) => r.queryParameters['page']);
    expect(pages, containsAll([0, 1]));
  });

  testWidgets('writing a review uploads the photo, then sends one review', (tester) async {
    final photo = File('${Directory.systemTemp.path}/ams-review-test.jpg')..writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    addTearDown(() => photo.existsSync() ? photo.deleteSync() : null);
    final h = await pumpAt(tester, '/reviews/destination/$angkorWat', signedIn: true, picker: () async => [photo.path]);

    await tester.tap(find.text('Write a review'));
    await settle(tester);
    expect(find.text('Rate your experience'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(Stars), matching: find.byType(Icon)).at(4));
    await tester.tap(find.text('Couples'));
    await tester.enterText(find.byType(TextField).at(0), 'Sunrise worth the alarm');
    await tester.enterText(find.byType(TextField).at(1), List.generate(30, (i) => 'word$i').join(' '));
    await tester.tap(find.text('Add photos'));
    await settle(tester, rounds: 3);
    await tester.tap(find.text('Submit review'));
    await settle(tester);

    final upload = h.adapter.requests.firstWhere((r) => r.path == '/media/files');
    expect(upload.method, 'POST');
    expect(upload.queryParameters, {'type': 'review'});
    final sent = h.adapter.requests.firstWhere((r) => r.path == '/reviews' && r.method == 'POST');
    final body = sent.data as Map;
    final now = DateTime.now();
    expect(body['targetType'], 'DESTINATION');
    expect(body['targetId'], angkorWat);
    expect(body['rating'], 5);
    expect(body['title'], 'Sunrise worth the alarm');
    expect(body['visitType'], 'COUPLES');
    expect(body['visitedOn'], '${now.year}-${now.month.toString().padLeft(2, '0')}');
    expect(body['photoKeys'], ['review/0b8c1f3e/photo-1.jpg']);
    expect(h.calls.indexOf('POST /media/files'), lessThan(h.calls.indexOf('POST /reviews')));

    // The server holds it for approval; back on the list.
    expect(find.text('Thanks — your review shows once it is approved'), findsOneWidget);
    expect(h.router.state.uri.path, '/reviews/destination/$angkorWat');
  });
}
