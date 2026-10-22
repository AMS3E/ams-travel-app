import '../../core/config/api_config.dart';
import '../models/json_utils.dart';

/// A page of a paged answer: `{content, page: {size, number, totalElements, totalPages}}`.
class PageOf<T> {
  const PageOf({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> content;

  /// From 0.
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get isLast => number + 1 >= totalPages;

  factory PageOf.fromJson(Json j, T Function(Json) item) {
    final page = obj(j, 'page');
    return PageOf(
      content: objList(j, 'content', item),
      number: integer(page, 'number'),
      size: integer(page, 'size'),
      totalElements: integer(page, 'totalElements'),
      totalPages: integer(page, 'totalPages'),
    );
  }
}

/// The box around a region's or a province's places, to frame a map.
class GeoBounds {
  const GeoBounds({required this.north, required this.south, required this.east, required this.west});

  final double north;
  final double south;
  final double east;
  final double west;

  static GeoBounds? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = Json.from(v);
    final n = dbl(j, 'north'), s = dbl(j, 'south'), e = dbl(j, 'east'), w = dbl(j, 'west');
    if (n == null || s == null || e == null || w == null) return null;
    return GeoBounds(north: n, south: s, east: e, west: w);
  }
}

/// What a card stands for. The API spells them in capitals.
enum CardType {
  destination('DESTINATION'),
  stay('STAY'),
  food('FOOD'),

  /// Something a traveller does rather than visits: a dive trip, a kayak
  /// tour, a trek, a cruise. Classed by its interests alone, like a stay.
  activity('ACTIVITY'),
  corridor('CORRIDOR');

  const CardType(this.code);
  final String code;

  static CardType parse(String code) => tryParse(code) ?? CardType.destination;

  /// The kind with this [code]; null for anything else.
  static CardType? tryParse(String code) => values.where((t) => t.code == code).firstOrNull;
}

/// The one card every list is made of (`GET /search`, `GET /search/cards`).
/// A row needs nothing else. Fields a kind does not have are null.
class PlaceCard {
  const PlaceCard({
    required this.type,
    required this.id,
    required this.name,
    this.slug,
    this.shortDescription,
    required this.coverUrl,
    this.provinceId,
    this.provinceName,
    this.latitude,
    this.longitude,
    this.categoryIds = const [],
    this.categoryNames = const [],
    this.interestIds = const [],
    this.tourismRegionIds = const [],
    this.averageRating,
    this.ratingCount = 0,
    this.reviewCount = 0,
    this.verified = false,
    this.basis,
    this.travelerRecommended = false,
    this.priceFrom,
    this.currency,
    this.durationDays,
    this.openNow,
    this.todayHours,
    this.stopNames = const [],
    this.encodedPolyline,
    this.distanceMeters,
  });

  final CardType type;
  final String id;
  final String name;
  final String? slug;
  final String? shortDescription;

  /// Full link, ready for [AppImage]; empty when there is no cover.
  final String coverUrl;
  final String? provinceId;
  final String? provinceName;
  final double? latitude;
  final double? longitude;
  final List<String> categoryIds;
  final List<String> categoryNames;
  final List<String> interestIds;
  final List<String> tourismRegionIds;
  final double? averageRating;
  final int ratingCount;
  final int reviewCount;
  final bool verified;
  final String? basis;
  final bool travelerRecommended;

  /// Only a stay or a food place has a price (an activity has none yet).
  final double? priceFrom;
  final String? currency;

  /// Only a corridor has a duration.
  final int? durationDays;

  /// A food place open at this moment in Cambodia; null when no hours are known.
  final bool? openNow;

  /// A food place's hours today: "07:00-22:00" or "closed".
  final String? todayHours;

  /// A corridor's stops, in travel order.
  final List<String> stopNames;

  /// A corridor's whole route, Google encoded; null until calculated.
  final String? encodedPolyline;

  /// From the destination asked for, when the card was found with
  /// `type=DESTINATION&near=`; null on every other card.
  final int? distanceMeters;

  bool get hasPin => latitude != null && longitude != null;

  factory PlaceCard.fromJson(Json j) => PlaceCard(
    type: CardType.parse(str(j, 'type')),
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    shortDescription: strOrNull(j, 'shortDescription'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    provinceId: strOrNull(j, 'provinceId'),
    provinceName: strOrNull(j, 'provinceName'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    categoryIds: strList(j, 'categoryIds'),
    categoryNames: strList(j, 'categoryNames'),
    interestIds: strList(j, 'interestIds'),
    tourismRegionIds: strList(j, 'tourismRegionIds'),
    averageRating: dbl(j, 'averageRating'),
    ratingCount: integer(j, 'ratingCount'),
    reviewCount: integer(j, 'reviewCount'),
    verified: boolean(j, 'verified'),
    basis: strOrNull(j, 'basis'),
    travelerRecommended: boolean(j, 'travelerRecommended'),
    priceFrom: dbl(j, 'priceFrom'),
    currency: strOrNull(j, 'currency'),
    durationDays: intOrNull(j, 'durationDays'),
    openNow: boolOrNull(j, 'openNow'),
    todayHours: strOrNull(j, 'todayHours'),
    stopNames: strList(j, 'stopNames'),
    encodedPolyline: strOrNull(j, 'encodedPolyline'),
    distanceMeters: intOrNull(j, 'distanceMeters'),
  );
}

/// A region from `GET /regions`. Tourism regions are the Explore cards.
class CatalogRegion {
  const CatalogRegion({
    required this.id,
    required this.name,
    required this.code,
    required this.kind,
    this.description,
    required this.coverUrl,
    this.categoryIds = const [],
    this.tagIds = const [],
    this.interestIds = const [],
    this.sortOrder = 0,
    this.latitude,
    this.longitude,
    this.bounds,
    this.mapUrl = '',
    this.amsRecommended = false,
  });

  final String id;
  final String name;
  final String code;

  /// `TOURISM` or `ADMINISTRATIVE`.
  final String kind;

  /// HTML on the detail answer.
  final String? description;
  final String coverUrl;
  final List<String> categoryIds;
  final List<String> tagIds;
  final List<String> interestIds;
  final int sortOrder;

  /// The centre an editor set, else the middle of its places.
  final double? latitude;
  final double? longitude;
  final GeoBounds? bounds;

  /// The picture for the Map panel of the region's page; empty until staff
  /// set one.
  final String mapUrl;

  /// Staff marked the region: the "Recommended by AMS Travel" badge on its
  /// card and at the top of its page.
  final bool amsRecommended;

  bool get hasPin => latitude != null && longitude != null;

  factory CatalogRegion.fromJson(Json j) => CatalogRegion(
    id: str(j, 'id'),
    name: str(j, 'name'),
    code: str(j, 'code'),
    kind: str(j, 'kind'),
    description: strOrNull(j, 'description'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    categoryIds: strList(j, 'categoryIds'),
    tagIds: strList(j, 'tagIds'),
    interestIds: strList(j, 'interestIds'),
    sortOrder: integer(j, 'sortOrder'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    bounds: GeoBounds.fromJson(j['bounds']),
    mapUrl: ApiConfig.mediaUrl(strOrNull(j, 'mapUrl')),
    amsRecommended: boolean(j, 'amsRecommended'),
  );
}

/// An interest from `GET /interests`. Each belongs to one of six groups.
class CatalogInterest {
  const CatalogInterest({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.groupName,
    this.iconKey,
    this.coverUrl = '',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String groupName;
  final String? iconKey;

  /// The interest's picture; empty until staff set one.
  final String coverUrl;
  final int sortOrder;

  factory CatalogInterest.fromJson(Json j) => CatalogInterest(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: str(j, 'slug'),
    description: strOrNull(j, 'description'),
    groupName: str(j, 'groupName'),
    iconKey: strOrNull(j, 'iconKey'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    sortOrder: integer(j, 'sortOrder'),
  );
}

/// One of the six interest groups: the Explore chips.
class InterestGroup {
  const InterestGroup(this.name, this.interests);

  /// The group's name as the API spells it ("Attraction Sites").
  // TODO R-075: no Khmer group name from the API; [S.interestGroup] shows
  // the app's own Khmer for the six known groups.
  final String name;
  final List<CatalogInterest> interests;

  List<String> get interestIds => [for (final i in interests) i.id];

  /// The group's picture: the first of its interests that has one. The API
  /// keeps pictures on interests, not on groups. Empty when none has one.
  String get coverUrl => interests.map((i) => i.coverUrl).firstWhere((u) => u.isNotEmpty, orElse: () => '');

  /// The groups whose cards are not destinations, as the API names them.
  static const stays = 'Stays';
  static const food = 'Food';
  static const activities = 'Activities & Experiences';
  static const corridors = 'Tourism Corridors';

  /// The six groups in the order of the design's chip row.
  static const order = ['Attraction Sites', stays, food, 'Water', activities, corridors];

  /// The kind of card this group is made of, for the `type` of
  /// `GET /search`. Null for destinations: without a type the server answers
  /// destinations only.
  CardType? get cardType => switch (name) {
    stays => CardType.stay,
    food => CardType.food,
    activities => CardType.activity,
    corridors => CardType.corridor,
    _ => null,
  };

  /// The corridors group, whose interests are routes, not kinds of place.
  bool get isCorridors => name == corridors;

  static List<InterestGroup> of(List<CatalogInterest> interests) {
    final byGroup = <String, List<CatalogInterest>>{};
    for (final i in interests) {
      byGroup.putIfAbsent(i.groupName, () => []).add(i);
    }
    int rank(String name) {
      final i = order.indexOf(name);
      return i < 0 ? order.length : i;
    }

    final names = byGroup.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
    return [for (final n in names) InterestGroup(n, byGroup[n]!..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))];
  }
}

/// A province from `GET /provinces`.
class CatalogProvince {
  const CatalogProvince({
    required this.id,
    required this.name,
    required this.slug,
    this.regionId,
    this.coverUrl = '',
    this.latitude,
    this.longitude,
    this.bounds,
    this.placeCount = 0,
    this.averageRating,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? regionId;
  final String coverUrl;

  /// The capital town.
  final double? latitude;
  final double? longitude;
  final GeoBounds? bounds;

  /// Published attractions, stays and food places together.
  final int placeCount;

  /// Across those places, weighted by each one's rating count.
  final double? averageRating;
  final int reviewCount;

  bool get hasPin => latitude != null && longitude != null;

  factory CatalogProvince.fromJson(Json j) => CatalogProvince(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: str(j, 'slug'),
    regionId: strOrNull(j, 'regionId'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    bounds: GeoBounds.fromJson(j['bounds']),
    placeCount: integer(j, 'placeCount'),
    averageRating: dbl(j, 'averageRating'),
    reviewCount: integer(j, 'reviewCount'),
  );
}

/// One row of `GET /search/by-province`: a province and its first places.
class ProvinceGroup {
  const ProvinceGroup({
    required this.provinceId,
    required this.provinceName,
    required this.totalElements,
    this.content = const [],
  });

  final String provinceId;
  final String provinceName;

  /// Every match in the province, beyond the ones in [content].
  final int totalElements;
  final List<PlaceCard> content;

  factory ProvinceGroup.fromJson(Json j) => ProvinceGroup(
    provinceId: str(j, 'provinceId'),
    provinceName: str(j, 'provinceName'),
    totalElements: integer(j, 'totalElements'),
    content: objList(j, 'content', PlaceCard.fromJson),
  );
}

/// One row of `GET /popular`. After the browsed places come filler rows
/// (VERIFIED, TOP_RATED, CATALOGUE) with no browses.
class PopularItem {
  const PopularItem({required this.type, required this.id, this.browses = 0, this.reason});

  final CardType type;
  final String id;
  final int browses;

  /// MOST_BROWSED, VERIFIED, TOP_RATED or CATALOGUE.
  final String? reason;

  factory PopularItem.fromJson(Json j) => PopularItem(
    type: CardType.parse(str(j, 'type')),
    id: str(j, 'id'),
    browses: integer(j, 'browses'),
    reason: strOrNull(j, 'reason'),
  );
}
