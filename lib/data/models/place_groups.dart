import 'destination.dart';
import 'json_utils.dart';

class Province {
  const Province({
    required this.slug,
    required this.name,
    this.nameKh,
    required this.tagline,
    required this.image,
    required this.lat,
    required this.lng,
    this.rating,
    this.reviewCount,
  });

  final String slug;
  final String name;
  final String? nameKh;
  final String tagline;
  final String image;
  final double lat;
  final double lng;

  /// Province-level score. Until the API sends one, the UI averages the
  /// ratings of the places inside the province.
  final double? rating;
  final int? reviewCount;

  factory Province.fromJson(Json j) => Province(
    slug: str(j, 'slug'),
    name: str(j, 'name'),
    nameKh: strOrNull(j, 'nameKh', alt: ['name_kh']),
    tagline: str(j, 'tagline', alt: ['description']),
    image: str(j, 'image', alt: ['imageUrl', 'image_url']),
    lat: dbl(j, 'lat', alt: ['latitude']) ?? 12.5,
    lng: dbl(j, 'lng', alt: ['longitude']) ?? 104.9,
    rating: dbl(j, 'rating'),
    reviewCount: j['reviewCount'] == null && j['review_count'] == null
        ? null
        : integer(j, 'reviewCount', alt: ['review_count']),
  );

  Json toJson() => {
    'slug': slug,
    'name': name,
    'nameKh': nameKh,
    'tagline': tagline,
    'image': image,
    'lat': lat,
    'lng': lng,
    if (rating != null) 'rating': rating,
    if (reviewCount != null) 'reviewCount': reviewCount,
  };
}

/// A way of cutting the same places by theme (Temples, Food & Markets…).
class Interest {
  const Interest({
    required this.slug,
    required this.name,
    this.nameKh,
    required this.description,
    required this.image,
    this.icon,
    this.type = 'destinations',
    this.categories = const [],
    this.count,
  });

  final String slug;
  final String name;
  final String? nameKh;
  final String description;
  final String image;

  /// Icon key for the category card (temple, stay, food, water, activity, route).
  final String? icon;

  /// `destinations` (default) lists places; `corridors` lists tourism corridors.
  final String type;

  /// Destination categories that belong to this interest.
  final List<String> categories;

  /// How many places (or corridors) the interest covers, when the API sends it.
  final int? count;

  bool get isCorridors => type == 'corridors';

  factory Interest.fromJson(Json j) => Interest(
    slug: str(j, 'slug'),
    name: str(j, 'name'),
    nameKh: strOrNull(j, 'nameKh'),
    description: str(j, 'description'),
    image: str(j, 'image', alt: ['imageUrl', 'image_url']),
    icon: strOrNull(j, 'icon'),
    type: str(j, 'type', fallback: 'destinations'),
    categories: strList(j, 'categories'),
    count: j['count'] == null ? null : integer(j, 'count'),
  );

  Json toJson() => {
    'slug': slug,
    'name': name,
    'nameKh': nameKh,
    'description': description,
    'image': image,
    'icon': icon,
    'type': type,
    'categories': categories,
    'count': ?count,
  };
}

class Corridor {
  const Corridor({
    required this.slug,
    required this.name,
    required this.duration,
    required this.description,
    required this.image,
    this.sequential = true,
    this.stops = const [],
    this.days,
    this.itinerary = const [],
  });

  final String slug;
  final String name;

  /// e.g. "7 – 10 days" or "Flexible".
  final String duration;
  final String description;
  final String image;

  /// `false` for corridors that are a set of areas rather than one road
  /// (the Khmer Culinary corridor) — drawn without a connecting line.
  final bool sequential;
  final List<CorridorStop> stops;

  /// How many days the plan below takes, and the plan itself.
  final int? days;
  final List<CorridorDay> itinerary;

  factory Corridor.fromJson(Json j) => Corridor(
    slug: str(j, 'slug'),
    name: str(j, 'name'),
    duration: str(j, 'duration'),
    description: str(j, 'description'),
    image: str(j, 'image', alt: ['imageUrl', 'image_url']),
    sequential: j['sequential'] == null ? true : boolean(j, 'sequential'),
    stops: objList(j, 'stops', CorridorStop.fromJson),
    days: j['days'] == null ? null : integer(j, 'days'),
    itinerary: objList(j, 'itinerary', CorridorDay.fromJson),
  );

  Json toJson() => {
    'slug': slug,
    'name': name,
    'duration': duration,
    'description': description,
    'image': image,
    'sequential': sequential,
    if (days != null) 'days': days,
    if (itinerary.isNotEmpty) 'itinerary': [for (final d in itinerary) d.toJson()],
    'stops': stops.map((s) => s.toJson()).toList(),
  };
}

/// One day of a corridor: where it starts, where it ends, and what happens.
class CorridorDay {
  const CorridorDay({
    required this.day,
    required this.from,
    required this.to,
    required this.summary,
    this.places = const [],
  });

  final int day;
  final String from;
  final String to;
  final String summary;

  /// "region/slug" of the places this day takes in.
  final List<String> places;

  factory CorridorDay.fromJson(Json j) => CorridorDay(
    day: integer(j, 'day'),
    from: str(j, 'from'),
    to: str(j, 'to'),
    summary: str(j, 'summary', alt: ['detail', 'description']),
    places: strList(j, 'places', alt: ['destinations']),
  );

  Json toJson() => {
    'day': day,
    'from': from,
    'to': to,
    'summary': summary,
    if (places.isNotEmpty) 'places': places,
  };
}

class CorridorStop {
  const CorridorStop({required this.name, this.nameKh, required this.lat, required this.lng});

  final String name;
  final String? nameKh;
  final double lat;
  final double lng;

  factory CorridorStop.fromJson(Json j) => CorridorStop(
    name: str(j, 'name'),
    nameKh: strOrNull(j, 'nameKh'),
    lat: dbl(j, 'lat') ?? 0,
    lng: dbl(j, 'lng') ?? 0,
  );

  Json toJson() => {'name': name, 'nameKh': nameKh, 'lat': lat, 'lng': lng};
}

/// A step in a region's historical coverage (Ishanapura, Angkor…).
class Story {
  const Story({
    required this.slug,
    required this.region,
    required this.step,
    required this.name,
    this.knownAs,
    this.nameKh,
    required this.when,
    required this.period,
    required this.summary,
    required this.quote,
    this.body = const [],
    required this.location,
    required this.lat,
    required this.lng,
    this.photos = const [],
    this.relatedDestinations = const [],
  });

  final String slug;
  final String region;
  final int step;
  final String name;
  final String? knownAs;
  final String? nameKh;
  final String when;
  final String period;
  final String summary;
  final String quote;
  final List<String> body;
  final String location;
  final double lat;
  final double lng;
  final List<String> photos;
  final List<DestinationRef> relatedDestinations;

  factory Story.fromJson(Json j) => Story(
    slug: str(j, 'slug'),
    region: str(j, 'region'),
    step: integer(j, 'step'),
    name: str(j, 'name'),
    knownAs: strOrNull(j, 'knownAs'),
    nameKh: strOrNull(j, 'nameKh'),
    when: str(j, 'when'),
    period: str(j, 'period'),
    summary: str(j, 'summary'),
    quote: str(j, 'quote'),
    body: strList(j, 'body'),
    location: str(j, 'location'),
    lat: dbl(j, 'lat') ?? 0,
    lng: dbl(j, 'lng') ?? 0,
    photos: strList(j, 'photos'),
    relatedDestinations: objList(j, 'relatedDestinations', DestinationRef.fromJson),
  );
}
