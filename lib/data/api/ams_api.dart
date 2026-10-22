import 'dart:math';

import '../../core/network/api_client.dart';
import '../../core/utils/dates.dart';
import '../models/json_utils.dart';
import 'account.dart';
import 'catalog.dart';
import 'details.dart';

export '../../core/utils/fallback.dart';
export 'account.dart';
export 'catalog.dart';
export 'details.dart';

/// The AMS Travel API, one method per call the screens make. Paths and
/// fields follow `assets/docs/mobile/screens-to-api.md`.
///
/// Reads are public; the calls under "Signed in" need a session. Search,
/// filters and suggestions are always server calls: nothing is filtered on
/// the phone.
///
/// Content comes in the app's language ([khmer]): the search calls ask
/// `lang=km` and the server answers the cards in Khmer where written; detail
/// and reference answers carry the Khmer beside the English, and [_inLanguage]
/// reads it in place of the English, which stays when no Khmer is written.
class AmsApi {
  AmsApi(this.client);

  final ApiClient client;

  /// The app is in Khmer; set by the language setting.
  bool khmer = false;

  String? get _lang => khmer ? 'km' : null;

  /// The fields with a Khmer twin (`nameKm`, `descriptionKm`, …).
  // TODO R-074: only corridors carry `shortDescriptionKm` so far; the other
  // kinds keep their English short description.
  static const _twins = ['name', 'shortDescription', 'description', 'slogan', 'sloganBy', 'address', 'title', 'notes'];

  /// [j] with each Khmer twin in place of its English field when the app is
  /// in Khmer; the English stays where the twin is null.
  Json _inLanguage(Json j) {
    if (!khmer) return j;
    final out = Json.of(j);
    for (final field in _twins) {
      final km = strOrNull(j, '${field}Km');
      if (km != null) out[field] = km;
    }
    return out;
  }

  /// [_list] and [_one] for answers that carry Khmer twins.
  List<T> _listIn<T>(dynamic body, T Function(Json) item) => _list(body, (j) => item(_inLanguage(j)));

  T _oneIn<T>(dynamic body, T Function(Json) item) => item(_inLanguage(Json.from(body as Map)));

  static List<T> _list<T>(dynamic body, T Function(Json) item) =>
      (body as List? ?? const []).whereType<Map>().map((e) => item(Json.from(e))).toList();

  static T _one<T>(dynamic body, T Function(Json) item) => item(Json.from(body as Map));

  static PageOf<T> _page<T>(dynamic body, T Function(Json) item) => PageOf.fromJson(Json.from(body as Map), item);

  // ---------------------------------------------------------------- Search

  /// The filters `GET /search` and `GET /search/by-province` share.
  static Map<String, dynamic> _filters({
    String? q,
    CardType? type,
    String? regionId,
    String? provinceId,
    List<String> regionIds = const [],
    List<String> provinceIds = const [],
    List<String> categoryIds = const [],
    List<String> tagIds = const [],
    List<String> interestIds = const [],
    List<String> corridorIds = const [],
    bool travelerRecommended = false,
    String? near,
  }) => {
    'q': q,
    'type': type?.code,
    'regionId': regionId,
    'provinceId': provinceId,
    'regionIds': regionIds,
    'provinceIds': provinceIds,
    'categoryIds': categoryIds,
    'tagIds': tagIds,
    'interestIds': interestIds,
    // TODO R-072: the server does not filter on corridors yet and ignores it.
    'corridorIds': corridorIds,
    if (travelerRecommended) 'travelerRecommended': true,
    'near': near,
  };

  /// `GET /search`: published places by keyword and filters, name order,
  /// `size` at most 100. Several regions or provinces match any of them; a
  /// region id may be a zone or a tourism region. [near] (a destination id)
  /// orders the cards nearest first; with `type=DESTINATION` it keeps the
  /// attractions within [radiusKm] of it (0.1–50, 25 when left out), each
  /// with its `distanceMeters`. [travelerRecommended] keeps the seal holders.
  /// [corridorIds] asks for the places along those corridors (R-072).
  Future<PageOf<PlaceCard>> search({
    String? q,
    CardType? type,
    String? regionId,
    String? provinceId,
    List<String> regionIds = const [],
    List<String> provinceIds = const [],
    List<String> categoryIds = const [],
    List<String> tagIds = const [],
    List<String> interestIds = const [],
    List<String> corridorIds = const [],
    bool travelerRecommended = false,
    String? near,
    double? radiusKm,
    int page = 0,
    int size = 20,
    String? sort,
  }) async => _page(
    await client.get(
      '/search',
      query: {
        ..._filters(
          q: q,
          type: type,
          regionId: regionId,
          provinceId: provinceId,
          regionIds: regionIds,
          provinceIds: provinceIds,
          categoryIds: categoryIds,
          tagIds: tagIds,
          interestIds: interestIds,
          corridorIds: corridorIds,
          travelerRecommended: travelerRecommended,
          near: near,
        ),
        'radiusKm': radiusKm,
        'lang': _lang,
        'page': page,
        'size': size,
        'sort': sort,
      },
    ),
    PlaceCard.fromJson,
  );

  /// `GET /search/by-province`: the Provinces page in one answer: each
  /// province with its first [perProvince] matches (1–20), A to Z, provinces
  /// with no match left out.
  Future<List<ProvinceGroup>> searchByProvince({
    CardType? type,
    List<String> regionIds = const [],
    List<String> provinceIds = const [],
    List<String> interestIds = const [],
    List<String> categoryIds = const [],
    List<String> tagIds = const [],
    int perProvince = 8,
  }) async => _list(
    await client.get(
      '/search/by-province',
      query: {
        ..._filters(
          type: type,
          regionIds: regionIds,
          provinceIds: provinceIds,
          interestIds: interestIds,
          categoryIds: categoryIds,
          tagIds: tagIds,
        ),
        'perProvince': perProvince,
        'lang': _lang,
      },
    ),
    ProvinceGroup.fromJson,
  );

  /// `GET /search/cards`: the cards for known ids, in the order asked.
  /// The API takes 100 ids a call, so longer lists go in several at once.
  Future<List<PlaceCard>> cards(List<String> ids, {CardType? type}) async {
    if (ids.isEmpty) return const [];
    final chunks = await Future.wait([
      for (var i = 0; i < ids.length; i += 100)
        client.get(
          '/search/cards',
          query: {'ids': ids.sublist(i, min(i + 100, ids.length)), 'type': type?.code, 'lang': _lang},
        ),
    ]);
    final byId = {
      for (final json in chunks)
        for (final c in _list(json, PlaceCard.fromJson)) c.id: c,
    };
    return [for (final id in ids) ?byId[id]];
  }

  /// One card, for a detail page's rating, review count and seal.
  Future<PlaceCard?> card(String id, {CardType? type}) async => (await cards([id], type: type)).firstOrNull;

  /// `GET /search/suggest`: what the typed text could be, names starting
  /// with it first.
  Future<List<Suggestion>> suggest(String q, {int limit = 8}) async {
    if (q.trim().isEmpty) return const [];
    return _list(
      await client.get('/search/suggest', query: {'q': q.trim(), 'limit': limit, 'lang': _lang}),
      Suggestion.fromJson,
    );
  }

  /// `GET /destinations/nearby`: destinations around a point, nearest first.
  Future<List<PlaceDetail>> _nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int limit = 20,
  }) async => _list(
    await client.get(
      '/destinations/nearby',
      query: {'latitude': latitude, 'longitude': longitude, 'radiusKm': radiusKm, 'limit': limit},
    ),
    PlaceDetail.fromJson,
  );

  /// Nearby destinations as cards: the ids, then their rows in one call.
  Future<List<PlaceCard>> nearbyCards({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int limit = 20,
  }) async {
    final places = await _nearby(latitude: latitude, longitude: longitude, radiusKm: radiusKm, limit: limit);
    return cards([for (final p in places) p.id], type: CardType.destination);
  }

  // -------------------------------------------------------- Reference data

  /// Reference lists barely change, so each is fetched once per app run and
  /// shared (read-only: sort a copy). A failed fetch is forgotten, so the
  /// next call tries again.
  final _memo = <String, Future<Object>>{};

  Future<List<T>> _reference<T>(String name, Future<List<T>> Function() fetch) {
    final key = '$name:$_lang';
    final cached = _memo[key];
    if (cached != null) return cached as Future<List<T>>;
    final fresh = fetch().then(List<T>.unmodifiable);
    _memo[key] = fresh;
    fresh.then(
      (_) {},
      onError: (_) {
        _memo.remove(key);
      },
    );
    return fresh;
  }

  Future<List<CatalogInterest>> interests() =>
      _reference('interests', () async => _listIn(await client.get('/interests'), CatalogInterest.fromJson));

  Future<List<InterestGroup>> interestGroups() =>
      _reference('interestGroups', () async => InterestGroup.of(await interests()));

  /// Every corridor, for the search filters' list.
  Future<List<PlaceCard>> corridors() =>
      _reference('corridors', () async => (await search(type: CardType.corridor, size: 100)).content);

  Future<List<CatalogRegion>> tourismRegions() => _reference(
    'tourismRegions',
    () async => _listIn(await client.get('/regions', query: {'kind': 'TOURISM'}), CatalogRegion.fromJson),
  );

  /// `GET /regions/{id}`: banner, name, overview (HTML), category and tag ids.
  Future<CatalogRegion> region(String id) async => _oneIn(await client.get('/regions/$id'), CatalogRegion.fromJson);

  Future<List<CatalogProvince>> provinces() =>
      _reference('provinces', () async => _listIn(await client.get('/provinces'), CatalogProvince.fromJson));

  /// One province out of [provinces].
  Future<CatalogProvince> province(String id) async =>
      (await provinces()).firstWhere((p) => p.id == id, orElse: () => throw StateError('Province not found'));

  Future<List<Label>> categories() =>
      _reference('categories', () async => _listIn(await client.get('/categories'), Label.fromJson));

  Future<List<Label>> tags() => _reference('tags', () async => _listIn(await client.get('/tags'), Label.fromJson));

  /// `GET /amenities`: label, icon and group for each amenity slug.
  Future<List<Amenity>> amenities({String? level}) => _reference(
    'amenities:$level',
    () async => _list(await client.get('/amenities', query: {'level': level}), Amenity.fromJson),
  );

  // ---------------------------------------------------------------- Popular

  /// `GET /popular`: the most browsed places of one kind, filled up to
  /// [limit] with filler rows (VERIFIED, TOP_RATED, CATALOGUE), in rank order.
  Future<List<PopularItem>> _popularItems({
    CardType type = CardType.destination,
    List<String> regionIds = const [],
    List<String> provinceIds = const [],
    List<String> interestIds = const [],
    int limit = 10,
  }) async {
    final body = Json.from(
      await client.get(
        '/popular',
        query: {
          'type': type.code,
          'regionIds': regionIds,
          'provinceIds': provinceIds,
          'interestIds': interestIds,
          'limit': limit,
        },
      ) as Map,
    );
    return objList(body, 'items', PopularItem.fromJson);
  }

  /// Popular places as cards: the items, then their rows in one call.
  Future<List<PlaceCard>> popular({
    CardType type = CardType.destination,
    List<String> regionIds = const [],
    List<String> provinceIds = const [],
    List<String> interestIds = const [],
    int limit = 10,
  }) async {
    final items = await _popularItems(
      type: type,
      regionIds: regionIds,
      provinceIds: provinceIds,
      interestIds: interestIds,
      limit: limit,
    );
    return cards([for (final i in items) i.id], type: type);
  }

  /// `POST /popular/events`: a page was opened. Public; feeds Popular.
  Future<void> recordBrowse(CardType type, String id, {required String sessionId}) => client.post(
    '/popular/events',
    body: {'targetType': type.code, 'targetId': id, 'eventType': 'VIEW', 'sessionId': sessionId},
  );

  // ------------------------------------------------------------ Destinations

  /// `GET /destinations/{id}`.
  Future<PlaceDetail> destination(String id) async =>
      _oneIn(await client.get('/destinations/$id'), PlaceDetail.fromJson);

  /// `GET /media?ownerType=&ownerId=`: a gallery, in its order.
  Future<List<MediaItem>> media(CardType ownerType, String ownerId) async {
    final items = _list(
      await client.get('/media', query: {'ownerType': ownerType.code, 'ownerId': ownerId}),
      MediaItem.fromJson,
    );
    return items..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// `GET /ratings/summary`: averages and star counts.
  Future<List<RatingSummary>> _ratingSummaries(CardType type, List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list(
      await client.get('/ratings/summary', query: {'targetType': type.code, 'targetIds': ids}),
      RatingSummary.fromJson,
    );
  }

  /// One place's summary out of [ratingSummaries].
  Future<RatingSummary?> ratingSummary(CardType type, String id) async =>
      (await _ratingSummaries(type, [id])).where((r) => r.targetId == id).firstOrNull;

  // ---------------------------------------------------------- Stays and food

  /// `GET /stays/{id}`.
  Future<StayDetail> stay(String id) async => _oneIn(await client.get('/stays/$id'), StayDetail.fromJson);

  /// `GET /stay-rooms?stayId=`.
  Future<List<StayRoom>> rooms(String stayId) async =>
      _list(await client.get('/stay-rooms', query: {'stayId': stayId}), StayRoom.fromJson);

  Map<String, dynamic> _stayQuery({
    DateTime? checkIn,
    DateTime? checkOut,
    int rooms = 1,
    int adults = 2,
    int children = 0,
  }) => {
    if (checkIn != null) 'checkIn': Dates.isoDay(checkIn),
    if (checkOut != null) 'checkOut': Dates.isoDay(checkOut),
    'rooms': rooms,
    'adults': adults,
    'children': children,
  };

  /// `GET /stay-rooms/quote`: one total per room for the chosen nights.
  /// Dates default to tonight on the server. A price preview, not a booking.
  Future<StayQuote> quote(
    String stayId, {
    DateTime? checkIn,
    DateTime? checkOut,
    int rooms = 1,
    int adults = 2,
    int children = 0,
  }) async => _one(
    await client.get(
      '/stay-rooms/quote',
      query: {
        'stayId': stayId,
        ..._stayQuery(checkIn: checkIn, checkOut: checkOut, rooms: rooms, adults: adults, children: children),
      },
    ),
    StayQuote.fromJson,
  );

  /// `GET /stay-rooms/{id}/quote`: the same for one room.
  Future<RoomQuote> roomQuote(
    String roomId, {
    DateTime? checkIn,
    DateTime? checkOut,
    int rooms = 1,
    int adults = 2,
    int children = 0,
  }) async => _one(
    await client.get(
      '/stay-rooms/$roomId/quote',
      query: _stayQuery(checkIn: checkIn, checkOut: checkOut, rooms: rooms, adults: adults, children: children),
    ),
    RoomQuote.fromJson,
  );

  /// `GET /foods/{id}`.
  Future<FoodDetail> food(String id) async => _oneIn(await client.get('/foods/$id'), FoodDetail.fromJson);

  // -------------------------------------------------------------- Activities

  /// `GET /activities/{id}`: a dive trip, a kayak tour, a trek, a cruise.
  Future<ActivityDetail> activity(String id) async =>
      _oneIn(await client.get('/activities/$id'), ActivityDetail.fromJson);

  // ---------------------------------------------------------------- Corridors

  /// `GET /corridors/{id}`.
  Future<CorridorDetail> corridor(String id) async =>
      _oneIn(await client.get('/corridors/$id'), CorridorDetail.fromJson);

  /// `GET /corridors/{id}/itinerary`: days, stops and the route line.
  ///
  /// In Khmer, the corridor, its days and stops take their Khmer twins, and
  /// each stop's place its Khmer name, province and short description from
  /// its card: the
  /// itinerary carries the place without them (R-076).
  Future<CorridorItinerary> itinerary(String id) async {
    final j = Json.from(await client.get('/corridors/$id/itinerary') as Map);
    if (!khmer) return CorridorItinerary.fromJson(j);
    List<Json> maps(Object? list) => (list as List? ?? const []).whereType<Map>().map(Json.from).toList();
    final days = maps(j['days']);
    final placeIds = [
      for (final d in days)
        for (final s in maps(d['stops']))
          if ((s['destination'] as Map?)?['id'] case final String id) id,
    ];
    var cards = <String, PlaceCard>{};
    try {
      cards = {for (final c in await this.cards(placeIds.toSet().toList(), type: CardType.destination)) c.id: c};
    } catch (_) {
      // The places keep their English.
    }
    Json place(Json d) {
      final out = _inLanguage(d);
      if (cards[d['id']] case final c?) {
        out['name'] = c.name;
        if (c.provinceName != null) out['provinceName'] = c.provinceName;
        // TODO R-074: the cards keep this in English for now.
        if (c.shortDescription != null) out['shortDescription'] = c.shortDescription;
      }
      return out;
    }

    return CorridorItinerary.fromJson({
      ...j,
      if (j['corridor'] is Map) 'corridor': _inLanguage(Json.from(j['corridor'] as Map)),
      'days': [
        for (final d in days)
          {
            ..._inLanguage(d),
            'stops': [
              for (final s in maps(d['stops']))
                {
                  ..._inLanguage(s),
                  if (s['destination'] is Map) 'destination': place(Json.from(s['destination'] as Map)),
                },
            ],
          },
      ],
    });
  }

  // ------------------------------------------------------------------ Reviews

  /// `GET /reviews?targetType=&targetId=` (public), newest first; [rating]
  /// keeps the reviews that gave those stars.
  Future<PageOf<TravelReview>> reviews(
    CardType type,
    String targetId, {
    List<int> rating = const [],
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async => _page(
    await client.get(
      '/reviews',
      query: {
        'targetType': type.code,
        'targetId': targetId,
        'rating': rating,
        'page': page,
        'size': size,
        'sort': sort,
      },
    ),
    TravelReview.fromJson,
  );

  /// `GET /reviews/{id}`.
  Future<TravelReview> review(String id) async => _one(await client.get('/reviews/$id'), TravelReview.fromJson);

  // -------------------------------------------------------------- Signed in

  /// `GET /users/me`.
  Future<UserProfile> me() async => _one(await client.get('/users/me'), UserProfile.fromJson);

  /// `PUT /users/me`. It carries the whole profile: a field left out is
  /// cleared, so every field is sent each time.
  Future<UserProfile> updateMe({
    required String? fullName,
    required String? phone,
    required String? avatarKey,
    required String? homeProvinceId,
  }) async => _one(
    await client.put(
      '/users/me',
      body: {'fullName': fullName, 'phone': phone, 'avatarKey': avatarKey, 'homeProvinceId': homeProvinceId},
    ),
    UserProfile.fromJson,
  );

  /// `GET /preferences/me`.
  Future<UserPreferences> preferences() async => _one(await client.get('/preferences/me'), UserPreferences.fromJson);

  /// `PUT /preferences/me`.
  Future<UserPreferences> savePreferences(UserPreferences prefs) async =>
      _one(await client.put('/preferences/me', body: prefs.toJson()), UserPreferences.fromJson);

  /// `POST /media/files?type=`: uploads a photo (type `review` or `avatar`)
  /// and returns the key to send with the review or the profile.
  Future<UploadedFile> uploadFile(String filePath, {required String type}) async =>
      _one(await client.upload('/media/files', filePath: filePath, query: {'type': type}), UploadedFile.fromJson);

  /// `POST /reviews`.
  Future<TravelReview> createReview(CardType type, String targetId, ReviewDraft draft) async => _one(
    await client.post('/reviews', body: {'targetType': type.code, 'targetId': targetId, ...draft.toJson()}),
    TravelReview.fromJson,
  );

  /// `PUT /reviews/{id}`.
  Future<TravelReview> updateReview(String id, ReviewDraft draft) async =>
      _one(await client.put('/reviews/$id', body: draft.toJson()), TravelReview.fromJson);

  /// `DELETE /reviews/{id}`.
  Future<void> deleteReview(String id) => client.delete('/reviews/$id');

  /// `GET /reviews/me`, newest first by default; [rating] keeps those stars.
  Future<PageOf<TravelReview>> myReviews({
    List<int> rating = const [],
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async => _page(
    await client.get('/reviews/me', query: {'rating': rating, 'page': page, 'size': size, 'sort': sort}),
    TravelReview.fromJson,
  );

  /// `GET /favorites`.
  Future<List<Favorite>> favorites() async => _list(await client.get('/favorites'), Favorite.fromJson);

  /// `POST /favorites`.
  Future<void> addFavorite(FavoriteType type, String targetId) =>
      client.post('/favorites', body: {'targetType': type.code, 'targetId': targetId});

  /// `DELETE /favorites/{type}/{id}`.
  Future<void> removeFavorite(FavoriteType type, String targetId) => client.delete('/favorites/${type.code}/$targetId');

  /// `GET /notifications`, newest first.
  Future<List<InboxNotification>> notifications({bool unreadOnly = false, int limit = 50}) async => _list(
    await client.get('/notifications', query: {'unreadOnly': unreadOnly, 'limit': limit}),
    InboxNotification.fromJson,
  );

  Future<void> markNotificationRead(String id) => client.put('/notifications/$id/read');

  Future<void> markAllNotificationsRead() => client.put('/notifications/read-all');

  Future<void> deleteNotification(String id) => client.delete('/notifications/$id');

  /// `GET /stamps/me`: the places checked in at.
  Future<List<Stamp>> myStamps() async => _list(await client.get('/stamps/me'), Stamp.fromJson);

  /// `POST /stamps`: a check-in with the code posted on site (the whole
  /// scanned text, or the code typed from under the print) and where the
  /// phone stands. The answer names the place the code belongs to.
  Future<Stamp> checkIn(String code, {required double latitude, required double longitude}) async => _one(
    await client.post('/stamps', body: {'code': code.trim(), 'latitude': latitude, 'longitude': longitude}),
    Stamp.fromJson,
  );

  /// `GET /points/me`.
  Future<PageOf<PointEntry>> myPoints({String? seasonId, int page = 0, int size = 20}) async => _page(
    await client.get('/points/me', query: {'seasonId': seasonId, 'page': page, 'size': size}),
    PointEntry.fromJson,
  );

  /// `PUT /badges/me/explorations/{id}`: a signed-in browse of an
  /// attraction, stay, food place or activity (Browser badge, and Popular).
  Future<BadgeProgress> recordExploration(String id) async =>
      _one(await client.put('/badges/me/explorations/$id'), BadgeProgress.fromJson);

  // ------------------------------------------------------------------ Badges

  /// `GET /badges` (public): every definition with its threshold.
  Future<List<BadgeDefinition>> badges() =>
      _reference('badges', () async => _list(await client.get('/badges'), BadgeDefinition.fromJson));

  /// `GET /badges/me/progress`.
  Future<BadgeProgress> badgeProgress({String? seasonId}) async =>
      _one(await client.get('/badges/me/progress', query: {'seasonId': seasonId}), BadgeProgress.fromJson);

  /// `GET /badges/me/earned`.
  Future<List<UserBadge>> earnedBadges() async => _list(await client.get('/badges/me/earned'), UserBadge.fromJson);

  /// `GET /seasons` (public): every season, past, current and to come.
  Future<List<Season>> seasons() async => _list(await client.get('/seasons'), Season.fromJson);

  /// `GET /seasons/current` (public).
  Future<Season> currentSeason() async => _one(await client.get('/seasons/current'), Season.fromJson);

  /// `GET /seasons/me/progress`: the traveller's totals in a season, the
  /// active one when [seasonId] is left out. Points live here since the
  /// points ladder was retired.
  Future<SeasonProgress> seasonProgress({String? seasonId}) async =>
      _one(await client.get('/seasons/me/progress', query: {'seasonId': seasonId}), SeasonProgress.fromJson);

  /// `GET /seasons/me/history`.
  Future<List<SeasonProgress>> seasonHistory() async =>
      _list(await client.get('/seasons/me/history'), SeasonProgress.fromJson);
}
