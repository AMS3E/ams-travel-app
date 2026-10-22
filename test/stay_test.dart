import 'package:ams_travel/features/destination/booking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'destination_harness.dart';

/// Two nights from tomorrow, so the panel shows the stay card at once.
Booking _twoNights() {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day + 1);
  return Booking(
    nights: DateTimeRange(start: from, end: from.add(const Duration(days: 2))),
    rooms: 1,
    adults: 2,
    children: 0,
  );
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpDestinationTests();

  testWidgets('a stay: stars, rating summary, amenities, policies, contacts, and one total', (tester) async {
    final booking = _twoNights();
    Booking.remember(riversideLodge, booking);
    final h = await pumpAt(tester, '/stays/$riversideLodge');

    expect(find.text('Angkor Riverside Lodge'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('4.3'), findsWidgets);
    expect(find.textContaining('8 reviews'), findsOneWidget);
    // Amenity slugs by name from GET /amenities.
    for (final a in ['Wi-Fi', 'Swimming pool', 'Air conditioning', 'Breakfast', 'Parking']) {
      expect(find.text(a), findsOneWidget, reason: a);
    }
    expect(find.text('Check-in: From 2PM until 10PM'), findsOneWidget);
    expect(find.text('Check-out: Before 12PM'), findsOneWidget);
    expect(find.text('No smoking in the rooms'), findsOneWidget);
    expect(find.text('+855 12 345 678'), findsOneWidget);
    expect(find.text('riverside.example.com'), findsOneWidget);
    expect(find.text('"Wake up to the river, sleep after the temples."'), findsOneWidget);
    // "Open 24h" is design filler on a stay.
    expect(find.text('Open 24 hours'), findsNothing);

    // The price is the quote's one total, never a nightly rate.
    expect(find.textContaining(r'US$175 total for 2 nights'), findsOneWidget);
    expect(find.textContaining('night selected'), findsNothing);
    expect(find.textContaining(r'$60'), findsNothing);
    expect(find.text('A price preview. Contact the stay to book.'), findsOneWidget);

    final quote = h.adapter.requests.firstWhere((r) => r.path == '/stay-rooms/quote');
    expect(quote.queryParameters, {
      'stayId': riversideLodge,
      'checkIn': _day(booking.nights.start),
      'checkOut': _day(booking.nights.end),
      'rooms': 1,
      'adults': 2,
      'children': 0,
    });
    expect(
      h.calls,
      containsAll(['GET /stays/$riversideLodge', 'GET /media', 'GET /amenities', 'GET /ratings/summary']),
    );
  });

  testWidgets('rooms show each quote total and why a room does not suit', (tester) async {
    Booking.remember(riversideLodge, _twoNights());
    final h = await pumpAt(tester, '/stays/$riversideLodge/rooms');

    expect(find.text('Deluxe King Room'), findsOneWidget);
    expect(find.text('Family Suite'), findsOneWidget);
    expect(find.text(r'US$175 total for 2 nights'), findsOneWidget);
    expect(find.text(r'US$320 total for 2 nights'), findsOneWidget);
    // Big per night (the total over its nights), the total under it.
    expect(find.text(r'US$87.50 / night'), findsOneWidget);
    // The rooms' amenity groups, not each amenity or the description.
    expect(find.text('Tech & work'), findsNWidgets(2));
    expect(find.text('Wi-Fi'), findsNothing);
    expect(find.text('Balcony over the river'), findsNothing);
    expect(find.text('Minimum 3 nights'), findsOneWidget);
    expect(find.text('Sleeps 2'), findsOneWidget);
    expect(find.text('Breakfast included'), findsOneWidget);
    expect(find.text('Per night'), findsNothing);
    expect(find.textContaining(r'$80'), findsNothing);
    expect(h.calls, containsAll(['GET /stay-rooms', 'GET /stay-rooms/quote']));
  });

  testWidgets('a stay with no rooms says so', (tester) async {
    await pumpAt(tester, '/stays/$riversideLodge/rooms', overrides: {'/stay-rooms': '[]'});
    expect(find.text('No rooms listed'), findsOneWidget);
  });

  testWidgets('room details: capacity, size, beds, amenities by group, its own quote', (tester) async {
    Booking.remember(riversideLodge, _twoNights());
    final h = await pumpAt(tester, '/stays/$riversideLodge/rooms/$deluxeKing');

    expect(find.text('Deluxe King Room'), findsOneWidget);
    expect(find.text(r'US$175 total for 2 nights'), findsOneWidget);
    expect(find.text('Sleeps 2'), findsOneWidget);
    expect(find.text('Max 1 children'), findsOneWidget);
    expect(find.text('32 m²/344 ft²'), findsOneWidget);
    expect(find.text('1 king'), findsOneWidget);
    expect(find.text('Tech & work'), findsOneWidget);
    expect(find.text('Wi-Fi  ·  TV'), findsOneWidget);
    expect(find.text('A king bed facing the river, with a balcony.'), findsOneWidget);
    expect(find.text('+855 12 345 678'), findsOneWidget);
    expect(h.calls, contains('GET /stay-rooms/$deluxeKing/quote'));
  });

  testWidgets('a food place: price range, cuisines, meals, week hours, contacts, nearby food', (tester) async {
    final h = await pumpAt(tester, '/foods/$banteayKitchen');

    expect(find.text('Banteay Kitchen'), findsOneWidget);
    expect(find.text(r'$5–15'), findsOneWidget);
    expect(find.text('4.5'), findsWidgets);
    expect(find.text('Khmer, Street food'), findsOneWidget);
    expect(find.text('Breakfast   Lunch   Dinner'), findsOneWidget);
    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('7AM–10PM'), findsNWidgets(4));
    expect(find.text('7AM–11PM'), findsNWidgets(2));
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('+855 17 222 333'), findsOneWidget);
    expect(find.text('banteay.example.com'), findsOneWidget);
    expect(find.text('"Cooked the way grandmother did."'), findsOneWidget);
    // Other food near the same place, without this one.
    expect(find.text('Food nearby'), findsOneWidget);
    expect(find.text('Psar Chas Noodles'), findsOneWidget);
    expect(find.text('Menu'), findsNothing);
    expect(find.text('Open now'), findsOneWidget, reason: "the server's openNow");
    expect(find.text('Today 7AM–10PM'), findsOneWidget, reason: "the server's todayHours");
    expect(h.calls, containsAll(['GET /foods/$banteayKitchen', 'GET /media', 'GET /search', 'GET /reviews']));
  });
}
