import 'dart:convert';
import 'dart:io';

import 'package:ams_travel/core/utils/geo.dart';
import 'package:ams_travel/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mock JSON has the shape the API should return. If these parse, the
/// same `fromJson` code will parse the backend's responses.
dynamic _read(String name) => jsonDecode(File('assets/mock/$name.json').readAsStringSync());

List<T> _list<T>(String name, T Function(Json) fromJson) =>
    (_read(name) as List).map((e) => fromJson(Json.from(e as Map))).toList();

void main() {
  final destinations = _list('destinations', Destination.fromJson);
  final regions = _list('regions', Region.fromJson);
  final provinces = _list('provinces', Province.fromJson);
  final interests = _list('interests', Interest.fromJson);
  final corridors = _list('corridors', Corridor.fromJson);
  final stories = _list('stories', Story.fromJson);
  final home = HomeContent.fromJson(Json.from(_read('home') as Map));
  final keys = destinations.map((d) => d.key).toSet();

  test('sizes match the website', () {
    expect(regions, hasLength(9));
    expect(provinces, hasLength(25));
    expect(interests, hasLength(6));
    expect(corridors, hasLength(5));
    expect(stories, hasLength(8));
    expect(destinations.length, greaterThan(190));
  });

  test('destination keys are unique and have coordinates inside Cambodia', () {
    expect(keys, hasLength(destinations.length));
    for (final d in destinations) {
      expect(d.lat, inInclusiveRange(9.5, 15), reason: d.key);
      expect(d.lng, inInclusiveRange(102, 108), reason: d.key);
      expect(d.image, startsWith('https://'), reason: d.key);
    }
  });

  test('every destination belongs to a known region and province', () {
    final regionSlugs = regions.map((r) => r.slug).toSet();
    final provinceSlugs = provinces.map((p) => p.slug).toSet();
    for (final d in destinations) {
      expect(regionSlugs, contains(d.region), reason: d.key);
      expect(provinceSlugs, contains(slugify(d.province)), reason: '${d.key} → ${d.province}');
    }
  });

  test('interest categories exist and every destination belongs to an interest', () {
    final categories = destinations.map((d) => d.category).toSet();
    final covered = interests.expand((i) => i.categories).toSet();
    expect(covered.difference(categories), isEmpty, reason: 'unknown categories in interests.json');
    expect(categories.difference(covered), isEmpty, reason: 'categories not in any interest');
    expect(interests.where((i) => i.isCorridors).map((i) => i.slug), ['tourism-corridors']);
    // Card counts match the data.
    for (final i in interests) {
      final expected = i.isCorridors
          ? corridors.length
          : destinations.where((d) => i.categories.contains(d.category)).length;
      expect(i.count, expected, reason: i.slug);
    }
  });

  test('region reviews point at real regions', () {
    final regionSlugs = regions.map((r) => r.slug).toSet();
    final reviews = (_read('reviews') as List).map((e) => Json.from(e as Map)).toList();
    expect(reviews, isNotEmpty);
    for (final r in reviews) {
      expect(regionSlugs, contains(r['region']), reason: r['id'] as String);
      final review = Review.fromJson(r);
      expect(review.rating, inInclusiveRange(1, 5));
      expect(review.text, isNotEmpty);
    }
  });

  test('home, story and highlight references resolve', () {
    for (final f in home.featured) {
      expect(keys, contains(f.ref.key));
    }
    for (final t in home.trending) {
      expect(keys, contains(t.ref.key));
    }
    for (final s in stories) {
      for (final r in s.relatedDestinations) {
        expect(keys, contains(r.key), reason: s.slug);
      }
    }
    final storySlugs = stories.map((s) => s.slug).toSet();
    for (final h in regions.expand((r) => r.highlights)) {
      if (h.storySlug != null) expect(storySlugs, contains(h.storySlug));
    }
  });

  test('fromJson accepts common alternative API shapes', () {
    final d = Destination.fromJson({
      'slug': 'x',
      'region_slug': 'luxury',
      'name': 'X',
      'province': 'Kep',
      'category': 'Spa',
      'description': 'd',
      'latitude': '10.5',
      'longitude': 104.3,
      'image_url': 'https://example.com/x.jpg',
      'featured': 1,
    });
    expect(d.region, 'luxury');
    expect(d.lat, 10.5);
    expect(d.blurb, 'd');
    expect(d.featured, isTrue);

    final session = AuthSession.fromJson({
      'accessToken': 't',
      'user': {'_id': '1', 'name': 'sophea', 'email': 's@example.com'},
    });
    expect(session.token, 't');
    expect(session.user.username, 'sophea');
  });

  test('every stay has a price and rooms', () {
    final stays = _list('destinations', Destination.fromJson).where((d) => d.isStay).toList();
    expect(stays, isNotEmpty);
    final byStay = {
      for (final entry in _read('rooms') as List)
        (entry as Map)['destination'] as String: (entry['rooms'] as List).map((r) => Room.fromJson(Json.from(r))).toList(),
    };
    for (final stay in stays) {
      expect(stay.priceFrom, isNotNull, reason: '${stay.key} has no nightly price');
      final rooms = byStay[stay.key];
      expect(rooms, isNotNull, reason: '${stay.key} has no rooms');
      expect(rooms!, isNotEmpty, reason: '${stay.key} has no rooms');
      for (final room in rooms) {
        expect(room.pricePerNight, greaterThan(0), reason: '${room.name} in ${stay.key}');
      }
    }
  });

  test('every corridor has a day-by-day plan', () {
    final corridors = _list('corridors', Corridor.fromJson);
    for (final c in corridors) {
      expect(c.itinerary, isNotEmpty, reason: '${c.slug} has no itinerary');
      expect(c.days, c.itinerary.length, reason: '${c.slug} day count');
      for (var i = 0; i < c.itinerary.length; i++) {
        expect(c.itinerary[i].day, i + 1, reason: '${c.slug} days run in order');
        expect(c.itinerary[i].summary, isNotEmpty);
      }
    }
  });
}
