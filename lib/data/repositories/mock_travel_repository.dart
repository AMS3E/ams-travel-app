import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/api_config.dart';
import '../../core/utils/geo.dart';
import '../models/models.dart';
import 'travel_repository.dart';

/// Serves the JSON files in `assets/mock/`, which have the same shape the API
/// is expected to return. Parsing goes through the real `fromJson` factories,
/// so a response that parses here will parse from the backend too.
class MockTravelRepository implements TravelRepository {
  final Map<String, dynamic> _cache = {};
  final Map<String, List<Review>> _reviews = {};

  Future<dynamic> _load(String name) async {
    return _cache[name] ??= jsonDecode(await rootBundle.loadString('assets/mock/$name.json'));
  }

  Future<T> _delay<T>(T value) => Future.delayed(ApiConfig.mockLatency, () => value);

  Future<List<Destination>> _allDestinations() async =>
      (await _load('destinations') as List).map((e) => Destination.fromJson(Json.from(e))).toList();

  @override
  Future<HomeContent> getHome() async => _delay(HomeContent.fromJson(Json.from(await _load('home'))));

  @override
  Future<List<Region>> getRegions() async =>
      _delay((await _load('regions') as List).map((e) => Region.fromJson(Json.from(e))).toList());

  @override
  Future<Region> getRegion(String slug) async {
    final all = await getRegions();
    return all.firstWhere((r) => r.slug == slug, orElse: () => throw NotFoundException('Region'));
  }

  @override
  Future<List<Destination>> getDestinations({
    String? region,
    String? province,
    List<String>? categories,
    String? query,
  }) async {
    final q = query?.trim().toLowerCase();
    final all = await _allDestinations();
    return _delay(
      all.where((d) {
        if (region != null && d.region != region) return false;
        if (province != null && slugify(d.province) != province && d.province != province) return false;
        if (categories != null && categories.isNotEmpty && !categories.contains(d.category)) return false;
        if (q != null && q.isNotEmpty && !_matches(d, q)) return false;
        return true;
      }).toList(),
    );
  }

  @override
  Future<Destination> getDestination(String region, String slug) async {
    final all = await _allDestinations();
    return _delay(
      all.firstWhere((d) => d.region == region && d.slug == slug, orElse: () => throw NotFoundException('Destination')),
    );
  }

  @override
  Future<List<Destination>> getDestinationsByRefs(List<DestinationRef> refs) async {
    final all = {for (final d in await _allDestinations()) d.key: d};
    return _delay([for (final r in refs) ?all[r.key]]);
  }

  @override
  Future<List<Province>> getProvinces() async =>
      _delay((await _load('provinces') as List).map((e) => Province.fromJson(Json.from(e))).toList());

  @override
  Future<Province> getProvince(String slug) async {
    final all = await getProvinces();
    return all.firstWhere((p) => p.slug == slug, orElse: () => throw NotFoundException('Province'));
  }

  @override
  Future<List<Interest>> getInterests() async =>
      _delay((await _load('interests') as List).map((e) => Interest.fromJson(Json.from(e))).toList());

  @override
  Future<Interest> getInterest(String slug) async {
    final all = await getInterests();
    return all.firstWhere((i) => i.slug == slug, orElse: () => throw NotFoundException('Interest'));
  }

  @override
  Future<List<Corridor>> getCorridors() async =>
      _delay((await _load('corridors') as List).map((e) => Corridor.fromJson(Json.from(e))).toList());

  @override
  Future<Corridor> getCorridor(String slug) async {
    final all = await getCorridors();
    return all.firstWhere((c) => c.slug == slug, orElse: () => throw NotFoundException('Corridor'));
  }

  @override
  Future<List<Story>> getStories(String region) async => _delay(
    (await _load('stories') as List).map((e) => Story.fromJson(Json.from(e))).where((s) => s.region == region).toList()
      ..sort((a, b) => a.step.compareTo(b.step)),
  );

  @override
  Future<Story> getStory(String region, String slug) async {
    final all = await getStories(region);
    return all.firstWhere((s) => s.slug == slug, orElse: () => throw NotFoundException('Story'));
  }

  @override
  Future<List<Review>> getReviews(DestinationRef ref) async =>
      _delay(List.unmodifiable(_reviews[ref.key] ?? const <Review>[]));

  @override
  Future<List<Review>> getRegionReviews(String region) async {
    // Traveller reviews from the website, plus anything written on this
    // region's place pages during the session.
    final seeded = (await _load('reviews') as List)
        .map((e) => Json.from(e))
        .where((j) => j['region'] == region)
        .map(Review.fromJson);
    final written = _reviews.entries.where((e) => e.key.startsWith('$region/')).expand((e) => e.value);
    return _delay([...seeded, ...written]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<List<Review>> getMyReviews(String author) async {
    // Reviews written this session, plus the sample ones in assets/mock so the
    // page has something to show. TODO(api): swap for GET /me/reviews.
    final written = _reviews.entries
        .expand((e) => e.value.map((r) => (e.key, r)))
        .where((pair) => pair.$2.author == author)
        .map((pair) => Review(
              id: pair.$2.id,
              author: pair.$2.author,
              rating: pair.$2.rating,
              title: pair.$2.title,
              text: pair.$2.text,
              tripType: pair.$2.tripType,
              visitedOn: pair.$2.visitedOn,
              destination: pair.$1,
              createdAt: pair.$2.createdAt,
            ));
    final seeded = (await _load('my_reviews') as List)
        .map((e) => Json.from(e))
        .map((j) => Review.fromJson({...j, 'id': 'seed-${j['destination']}', 'author': author}));
    return _delay([...written, ...seeded]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<List<Room>> getRooms(DestinationRef ref) async {
    final all = await _load('rooms') as List;
    return _delay(
      all
          .map((e) => Json.from(e))
          .where((j) => j['destination'] == ref.key)
          .expand((j) => (j['rooms'] as List).map((r) => Room.fromJson(Json.from(r))))
          .toList(),
    );
  }

  @override
  Future<Review> submitReview(
    DestinationRef ref, {
    required int rating,
    String? title,
    String? text,
    String? tripType,
    DateTime? visitedOn,
    required String author,
  }) async {
    final list = _reviews.putIfAbsent(ref.key, () => []);
    list.removeWhere((r) => r.author == author);
    final review = Review(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: author,
      rating: rating,
      title: title,
      text: text,
      tripType: tripType,
      visitedOn: visitedOn,
      createdAt: DateTime.now(),
    );
    list.insert(0, review);
    return _delay(review);
  }

  @override
  Future<void> submitPlanRequest({required String email, required String destination}) => _delay(null);

  @override
  Future<SearchResults> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const SearchResults();
    bool has(String? s) => s != null && s.toLowerCase().contains(q);
    final regions = (await _load('regions') as List)
        .map((e) => Region.fromJson(Json.from(e)))
        // Also match "Ancient Capitals & Khmer Civilization Region" → the region
        // named "Ancient Capitals & Khmer Civilization".
        .where((r) => has(r.name) || has(r.nameKh) || has(r.summary) || q.contains(r.name.toLowerCase()))
        .toList();
    final provinces = (await _load('provinces') as List)
        .map((e) => Province.fromJson(Json.from(e)))
        .where((p) => has(p.name) || has(p.nameKh) || has(p.tagline))
        .toList();
    final interests = (await _load('interests') as List)
        .map((e) => Interest.fromJson(Json.from(e)))
        .where((i) => has(i.name) || has(i.nameKh) || i.categories.any(has))
        .toList();
    final corridors = (await _load('corridors') as List)
        .map((e) => Corridor.fromJson(Json.from(e)))
        .where((c) => has(c.name) || has(c.description) || c.stops.any((s) => has(s.name) || has(s.nameKh)))
        .toList();
    return _delay(SearchResults(regions: regions, provinces: provinces, interests: interests, corridors: corridors));
  }

  static bool _matches(Destination d, String q) {
    bool has(String? s) => s != null && s.toLowerCase().contains(q);
    return has(d.name) || has(d.nameKh) || has(d.province) || has(d.category) || has(d.blurb) || d.tags.any(has);
  }
}
