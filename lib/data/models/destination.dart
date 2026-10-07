import 'json_utils.dart';

/// Identifies a destination. On the website a place's URL is
/// `/regions/{region}/{slug}` and slugs are only unique within a region.
class DestinationRef {
  const DestinationRef(this.region, this.slug);

  final String region;
  final String slug;

  String get key => '$region/$slug';

  factory DestinationRef.fromKey(String key) {
    final i = key.indexOf('/');
    return DestinationRef(key.substring(0, i), key.substring(i + 1));
  }

  factory DestinationRef.fromJson(Json j) =>
      DestinationRef(str(j, 'region', alt: ['regionSlug', 'region_slug']), str(j, 'slug'));

  Json toJson() => {'region': region, 'slug': slug};

  @override
  bool operator ==(Object other) => other is DestinationRef && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class Destination {
  const Destination({
    required this.slug,
    required this.region,
    required this.name,
    this.nameKh,
    required this.province,
    required this.category,
    required this.blurb,
    this.detail,
    this.rating,
    this.featured = false,
    this.verified = false,
    this.unesco = false,
    required this.lat,
    required this.lng,
    required this.image,
    this.images = const [],
    this.tags = const [],
    this.facets = const {},
    this.facilities = const [],
    this.openTime,
    this.closeTime,
    this.open24h = false,
    this.reviewCount,
    this.stars,
    this.priceFrom,
    this.currency = 'USD',
    this.entryFee,
    this.visitDuration,
    this.bestTime,
    this.bestSeason,
    this.priceRange,
    this.difficulty,
    this.groupSize,
    this.highlights = const [],
    this.tips = const [],
    this.website,
    this.phone,
    this.email,
    this.telegram,
  });

  final String slug;
  final String region;
  final String name;
  final String? nameKh;
  final String province;
  final String category;
  final String blurb;
  final String? detail;
  final double? rating;
  final bool featured;
  final bool verified;
  final bool unesco;
  final double lat;
  final double lng;
  final String image;

  /// Extra photos for the gallery; [image] is the cover.
  final List<String> images;

  /// Cover first, then the rest — what the gallery shows.
  List<String> get gallery => [image, ...images.where((u) => u != image)];

  final List<String> tags;

  /// Extra attributes shown in "At a glance" (Century, King, Religion…).
  final Map<String, String> facets;
  final List<String> facilities;

  /// Opening hours as "HH:mm" in Cambodia time; `closeTime` earlier than
  /// `openTime` means it closes after midnight. Null = not listed.
  final String? openTime;
  final String? closeTime;
  final bool open24h;

  /// Number of reviews behind [rating], when the API provides it.
  final int? reviewCount;

  /// Nightly price for a stay, shown in the booking bar. Null hides the bar.
  /// TODO(api): send `priceFrom` (and `currency`) for hotels and homestays.
  /// How a stay is classified: 5 for a five-star hotel.
  final int? stars;

  final double? priceFrom;
  final String currency;

  /// Practical detail shown in "Good to know". Which of these a place uses
  /// depends on its category — a temple lists an entry fee and how long to
  /// allow, a restaurant a price range, a trek its difficulty.
  final String? entryFee;
  final String? visitDuration;
  final String? bestTime;
  final String? bestSeason;
  final String? priceRange;
  final String? difficulty;
  final String? groupSize;

  /// Dishes to try, things to do, what a tour includes — the heading depends
  /// on the category.
  final List<String> highlights;

  /// Short practical notes ("Bring sandals", "Dress covering shoulders").
  final List<String> tips;

  /// Ways to reach the place. Each is shown only when the API sends it.
  final String? website;
  final String? phone;
  final String? email;
  final String? telegram;

  /// Places you sleep in — they get the stay layout (facilities, policies,
  /// nightly price) instead of the sightseeing one.
  static const stayCategories = {'Homestay', 'Eco Lodge', 'Luxury Hotel', 'Private Island'};
  bool get isStay => stayCategories.contains(category);

  DestinationRef get ref => DestinationRef(region, slug);
  String get key => ref.key;

  factory Destination.fromJson(Json j) {
    final rawFacets = j['facets'];
    return Destination(
      slug: str(j, 'slug'),
      region: str(j, 'region', alt: ['regionSlug', 'region_slug']),
      name: str(j, 'name'),
      nameKh: strOrNull(j, 'nameKh', alt: ['name_kh']),
      province: str(j, 'province'),
      category: str(j, 'category'),
      blurb: str(j, 'blurb', alt: ['summary', 'description']),
      detail: strOrNull(j, 'detail'),
      rating: dbl(j, 'rating'),
      featured: boolean(j, 'featured'),
      verified: boolean(j, 'verified'),
      unesco: boolean(j, 'unesco'),
      lat: dbl(j, 'lat', alt: ['latitude']) ?? 0,
      lng: dbl(j, 'lng', alt: ['longitude', 'lon']) ?? 0,
      image: str(j, 'image', alt: ['imageUrl', 'image_url']),
      images: strList(j, 'images', alt: ['photos', 'gallery']),
      tags: strList(j, 'tags'),
      facets: rawFacets is Map ? rawFacets.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
      facilities: strList(j, 'facilities'),
      openTime: strOrNull(j, 'openTime', alt: ['open_time', 'opensAt']),
      closeTime: strOrNull(j, 'closeTime', alt: ['close_time', 'closesAt']),
      open24h: boolean(j, 'open24h', alt: ['open_24h']),
      reviewCount: j['reviewCount'] == null && j['review_count'] == null
          ? null
          : integer(j, 'reviewCount', alt: ['review_count']),
      stars: j['stars'] == null ? null : integer(j, 'stars'),
    priceFrom: dbl(j, 'priceFrom', alt: ['price_from', 'price']),
      currency: strOrNull(j, 'currency') ?? 'USD',
      entryFee: strOrNull(j, 'entryFee', alt: ['entry_fee', 'ticket']),
      visitDuration: strOrNull(j, 'visitDuration', alt: ['visit_duration', 'duration']),
      bestTime: strOrNull(j, 'bestTime', alt: ['best_time']),
      bestSeason: strOrNull(j, 'bestSeason', alt: ['best_season', 'season']),
      priceRange: strOrNull(j, 'priceRange', alt: ['price_range']),
      difficulty: strOrNull(j, 'difficulty'),
      groupSize: strOrNull(j, 'groupSize', alt: ['group_size']),
      highlights: strList(j, 'highlights', alt: ['dishes', 'includes', 'things_to_do']),
      tips: strList(j, 'tips', alt: ['notes']),
      website: strOrNull(j, 'website', alt: ['url']),
      phone: strOrNull(j, 'phone', alt: ['tel', 'phoneNumber']),
      email: strOrNull(j, 'email'),
      telegram: strOrNull(j, 'telegram'),
    );
  }

  Json toJson() => {
    'slug': slug,
    'region': region,
    'name': name,
    if (nameKh != null) 'nameKh': nameKh,
    'province': province,
    'category': category,
    'blurb': blurb,
    if (detail != null) 'detail': detail,
    if (rating != null) 'rating': rating,
    'featured': featured,
    'verified': verified,
    'unesco': unesco,
    'lat': lat,
    'lng': lng,
    'image': image,
    if (images.isNotEmpty) 'images': images,
    'tags': tags,
    'facets': facets,
    'facilities': facilities,
    if (openTime != null) 'openTime': openTime,
    if (closeTime != null) 'closeTime': closeTime,
    if (open24h) 'open24h': true,
    if (reviewCount != null) 'reviewCount': reviewCount,
    if (priceFrom != null) 'priceFrom': priceFrom,
    if (priceFrom != null) 'currency': currency,
    if (entryFee != null) 'entryFee': entryFee,
    if (visitDuration != null) 'visitDuration': visitDuration,
    if (bestTime != null) 'bestTime': bestTime,
    if (bestSeason != null) 'bestSeason': bestSeason,
    if (priceRange != null) 'priceRange': priceRange,
    if (difficulty != null) 'difficulty': difficulty,
    if (groupSize != null) 'groupSize': groupSize,
    if (highlights.isNotEmpty) 'highlights': highlights,
    if (tips.isNotEmpty) 'tips': tips,
    if (website != null) 'website': website,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (telegram != null) 'telegram': telegram,
  };
}
