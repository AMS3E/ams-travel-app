import '../../core/config/api_config.dart';
import '../models/json_utils.dart';

Map<String, String> _stringMap(Object? v) =>
    v is Map ? v.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')) : const {};

/// A picture from `GET /media?ownerType=&ownerId=`, or a review photo.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.url,
    this.key,
    this.caption,
    this.sortOrder = 0,
    this.isCover = false,
  });

  final String id;

  /// Full link, ready for [AppImage].
  final String url;
  final String? key;
  final String? caption;
  final int sortOrder;
  final bool isCover;

  factory MediaItem.fromJson(Json j) => MediaItem(
    id: str(j, 'id'),
    url: ApiConfig.mediaUrl(strOrNull(j, 'mediaUrl')),
    key: strOrNull(j, 'mediaKey'),
    caption: strOrNull(j, 'caption'),
    sortOrder: integer(j, 'sortOrder'),
    isCover: boolean(j, 'isCover'),
  );
}

/// What `POST /media/files` answers: the key to send with a review or profile.
class UploadedFile {
  const UploadedFile({required this.key, required this.url});

  final String key;
  final String url;

  factory UploadedFile.fromJson(Json j) =>
      UploadedFile(key: str(j, 'key'), url: ApiConfig.mediaUrl(strOrNull(j, 'uri')));
}

/// `GET /categories`, `GET /tags`: id and label for the filter chips.
class Label {
  const Label({required this.id, required this.name, required this.slug, this.iconKey, this.sortOrder = 0});

  final String id;
  final String name;
  final String slug;
  final String? iconKey;
  final int sortOrder;

  factory Label.fromJson(Json j) => Label(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: str(j, 'slug'),
    iconKey: strOrNull(j, 'iconKey'),
    sortOrder: integer(j, 'sortOrder'),
  );
}

/// What a typing suggestion points at.
enum SuggestionKind { destination, stay, food, activity, corridor, province, region }

/// `GET /search/suggest`: names starting with the text first.
class Suggestion {
  const Suggestion({required this.kind, required this.id, required this.name, this.slug});

  final SuggestionKind kind;
  final String id;
  final String name;
  final String? slug;

  factory Suggestion.fromJson(Json j) => Suggestion(
    kind: SuggestionKind.values.firstWhere(
      (k) => k.name.toUpperCase() == str(j, 'kind'),
      orElse: () => SuggestionKind.destination,
    ),
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
  );
}

/// An attraction from `GET /destinations/{id}` (also the rows of
/// `GET /destinations/nearby`). Its rating, review count and seal come from
/// its card.
class PlaceDetail {
  const PlaceDetail({
    required this.id,
    required this.name,
    this.slug,
    this.provinceId,
    this.regionId,
    this.shortDescription,
    this.description,
    this.slogan,
    this.sloganBy,
    this.latitude,
    this.longitude,
    this.address,
    required this.coverUrl,
    this.categoryIds = const [],
    this.tagIds = const [],
    this.interestIds = const [],
    this.tourismRegionIds = const [],
    this.specialties = const [],
  });

  final String id;
  final String name;
  final String? slug;
  final String? provinceId;
  final String? regionId;
  final String? shortDescription;

  /// May be HTML.
  final String? description;
  final String? slogan;
  final String? sloganBy;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String coverUrl;
  final List<String> categoryIds;
  final List<String> tagIds;
  final List<String> interestIds;
  final List<String> tourismRegionIds;
  final List<String> specialties;

  bool get hasPin => latitude != null && longitude != null;

  factory PlaceDetail.fromJson(Json j) => PlaceDetail(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    provinceId: strOrNull(j, 'provinceId'),
    regionId: strOrNull(j, 'regionId'),
    shortDescription: strOrNull(j, 'shortDescription'),
    description: strOrNull(j, 'description'),
    slogan: strOrNull(j, 'slogan'),
    sloganBy: strOrNull(j, 'sloganBy'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    address: strOrNull(j, 'address'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    categoryIds: strList(j, 'categoryIds'),
    tagIds: strList(j, 'tagIds'),
    interestIds: strList(j, 'interestIds'),
    tourismRegionIds: strList(j, 'tourismRegionIds'),
    specialties: strList(j, 'specialties'),
  );
}

/// A stay from `GET /stays/{id}`. Of its many policy fields the design reads
/// the policies box, the check-in and check-out hours and the contacts.
class StayDetail {
  const StayDetail({
    required this.id,
    required this.name,
    this.destinationId,
    this.type,
    this.starRating,
    this.shortDescription,
    this.description,
    this.slogan,
    this.sloganBy,
    this.provinceId,
    this.policies,
    this.checkInFrom,
    this.checkInUntil,
    this.checkOutFrom,
    this.checkOutUntil,
    this.phone,
    this.contactEmail,
    this.website,
    this.telegram,
    this.whatsapp,
    this.facebookUrl,
    this.priceFrom,
    this.currency,
    this.amenities = const [],
    required this.coverUrl,
    this.address,
    this.latitude,
    this.longitude,
    this.interestIds = const [],
    this.weekendNights = const [],
    this.childrenAllowed,
    this.breakfastOption,
  });

  final String id;
  final String name;
  final String? destinationId;

  /// HOTEL, GUESTHOUSE, HOSTEL, RESORT, HOMESTAY, VILLA, OTHER.
  final String? type;
  final double? starRating;
  final String? shortDescription;
  final String? description;
  final String? slogan;
  final String? sloganBy;
  final String? provinceId;
  final String? policies;

  /// "HH:mm:ss".
  final String? checkInFrom;
  final String? checkInUntil;
  final String? checkOutFrom;
  final String? checkOutUntil;
  final String? phone;
  final String? contactEmail;
  final String? website;
  final String? telegram;
  final String? whatsapp;
  final String? facebookUrl;
  final double? priceFrom;
  final String? currency;

  /// Amenity slugs; labels, icons and groups come from `GET /amenities`.
  final List<String> amenities;
  final String coverUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> interestIds;

  /// Weekday names priced as weekend nights ("FRIDAY", "SATURDAY").
  final List<String> weekendNights;
  final bool? childrenAllowed;

  /// NONE, INCLUDED, EXTRA_CHARGE.
  final String? breakfastOption;

  bool get hasPin => latitude != null && longitude != null;

  factory StayDetail.fromJson(Json j) => StayDetail(
    id: str(j, 'id'),
    name: str(j, 'name'),
    destinationId: strOrNull(j, 'destinationId'),
    type: strOrNull(j, 'type'),
    starRating: dbl(j, 'starRating'),
    shortDescription: strOrNull(j, 'shortDescription'),
    description: strOrNull(j, 'description'),
    slogan: strOrNull(j, 'slogan'),
    sloganBy: strOrNull(j, 'sloganBy'),
    provinceId: strOrNull(j, 'provinceId'),
    policies: strOrNull(j, 'policies'),
    checkInFrom: strOrNull(j, 'checkInFrom'),
    checkInUntil: strOrNull(j, 'checkInUntil'),
    checkOutFrom: strOrNull(j, 'checkOutFrom'),
    checkOutUntil: strOrNull(j, 'checkOutUntil'),
    phone: strOrNull(j, 'phone'),
    contactEmail: strOrNull(j, 'contactEmail'),
    website: strOrNull(j, 'website'),
    telegram: strOrNull(j, 'telegram'),
    whatsapp: strOrNull(j, 'whatsapp'),
    facebookUrl: strOrNull(j, 'facebookUrl'),
    priceFrom: dbl(j, 'priceFrom'),
    currency: strOrNull(j, 'currency'),
    amenities: strList(j, 'amenities'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    address: strOrNull(j, 'address'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    interestIds: strList(j, 'interestIds'),
    weekendNights: strList(j, 'weekendNights'),
    childrenAllowed: boolOrNull(j, 'childrenAllowed'),
    breakfastOption: strOrNull(j, 'breakfastOption'),
  );
}

/// An amenity from `GET /amenities`: the label, icon and group for a slug.
class Amenity {
  const Amenity({
    required this.slug,
    required this.name,
    required this.groupName,
    this.iconKey,
    this.level,
    this.sortOrder = 0,
  });

  final String slug;
  final String name;
  final String groupName;
  final String? iconKey;

  /// PROPERTY, ROOM or BOTH.
  final String? level;
  final int sortOrder;

  factory Amenity.fromJson(Json j) => Amenity(
    slug: str(j, 'slug'),
    name: str(j, 'name'),
    groupName: str(j, 'groupName'),
    iconKey: strOrNull(j, 'iconKey'),
    level: strOrNull(j, 'level'),
    sortOrder: integer(j, 'sortOrder'),
  );
}

/// A room from `GET /stay-rooms?stayId=`. Its nightly prices are only for
/// working out a quote on the server; the app shows the quote's total.
class StayRoom {
  const StayRoom({
    required this.id,
    required this.stayId,
    required this.name,
    this.roomType,
    this.maxAdults,
    this.maxChildren,
    this.sleeps,
    this.sizeSqm,
    this.view,
    this.bathroom,
    this.breakfastIncluded = false,
    this.freeCancellationDays,
    this.amenities = const [],
    this.photoUrls = const [],
    this.description,
    this.highlight,
    this.currency,
    this.minNights,
    this.beds = const {},
  });

  final String id;
  final String stayId;
  final String name;
  final String? roomType;
  final int? maxAdults;
  final int? maxChildren;
  final int? sleeps;
  final double? sizeSqm;
  final String? view;
  final String? bathroom;
  final bool breakfastIncluded;
  final int? freeCancellationDays;

  /// Amenity slugs, grouped with `GET /amenities`.
  final List<String> amenities;
  final List<String> photoUrls;
  final String? description;
  final String? highlight;
  final String? currency;
  final int? minNights;

  /// Bed kind → how many, only the kinds the room has ("king": 1).
  final Map<String, int> beds;

  factory StayRoom.fromJson(Json j) => StayRoom(
    id: str(j, 'id'),
    stayId: str(j, 'stayId'),
    name: str(j, 'name'),
    roomType: strOrNull(j, 'roomType'),
    maxAdults: intOrNull(j, 'maxAdults'),
    maxChildren: intOrNull(j, 'maxChildren'),
    sleeps: intOrNull(j, 'sleeps'),
    sizeSqm: dbl(j, 'sizeSqm'),
    view: strOrNull(j, 'view'),
    bathroom: strOrNull(j, 'bathroom'),
    breakfastIncluded: boolean(j, 'breakfastIncluded'),
    freeCancellationDays: intOrNull(j, 'freeCancellationDays'),
    amenities: strList(j, 'amenities'),
    photoUrls: [for (final p in strList(j, 'photoUrls')) ApiConfig.mediaUrl(p)],
    description: strOrNull(j, 'description'),
    highlight: strOrNull(j, 'highlight'),
    currency: strOrNull(j, 'currency'),
    minNights: intOrNull(j, 'minNights'),
    beds: {
      for (final kind in const ['single', 'double', 'queen', 'king', 'bunk', 'sofa', 'futon'])
        if (integer(j, '${kind}Beds') > 0) kind: integer(j, '${kind}Beds'),
    },
  );
}

/// One room's price for the chosen nights, from the quote.
class RoomQuote {
  const RoomQuote({
    required this.roomId,
    required this.name,
    this.currency,
    required this.nights,
    this.weekendNightCount = 0,
    this.total,
    this.fitsGuests = true,
    this.enoughRooms = true,
    this.meetsMinNights = true,
    this.minNights,
    this.breakfastIncluded = false,
    this.taxesIncluded = false,
    this.bookable = false,
  });

  final String roomId;
  final String name;
  final String? currency;
  final int nights;
  final int weekendNightCount;

  /// What the stay costs for all the nights. The only price the app shows.
  final double? total;
  final bool fitsGuests;
  final bool enoughRooms;
  final bool meetsMinNights;
  final int? minNights;
  final bool breakfastIncluded;
  final bool taxesIncluded;
  final bool bookable;

  factory RoomQuote.fromJson(Json j) => RoomQuote(
    roomId: str(j, 'roomId'),
    name: str(j, 'name'),
    currency: strOrNull(j, 'currency'),
    nights: integer(j, 'nights'),
    weekendNightCount: integer(j, 'weekendNightCount'),
    total: dbl(j, 'total'),
    fitsGuests: boolOrNull(j, 'fitsGuests') ?? true,
    enoughRooms: boolOrNull(j, 'enoughRooms') ?? true,
    meetsMinNights: boolOrNull(j, 'meetsMinNights') ?? true,
    minNights: intOrNull(j, 'minNights'),
    breakfastIncluded: boolean(j, 'breakfastIncluded'),
    taxesIncluded: boolean(j, 'taxesIncluded'),
    bookable: boolean(j, 'bookable'),
  );
}

/// `GET /stay-rooms/quote`: a price preview for the stay, no booking.
class StayQuote {
  const StayQuote({
    required this.stayId,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.rooms,
    required this.adults,
    required this.children,
    this.currency,
    this.fromTotal,
    this.roomQuotes = const [],
  });

  final String stayId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int rooms;
  final int adults;
  final int children;
  final String? currency;

  /// The lowest total among the rooms that fit: "from US$300 for 2 nights".
  final double? fromTotal;
  final List<RoomQuote> roomQuotes;

  RoomQuote? forRoom(String roomId) {
    for (final q in roomQuotes) {
      if (q.roomId == roomId) return q;
    }
    return null;
  }

  factory StayQuote.fromJson(Json j) => StayQuote(
    stayId: str(j, 'stayId'),
    checkIn: dateOrNull(j, 'checkIn') ?? DateTime.now(),
    checkOut: dateOrNull(j, 'checkOut') ?? DateTime.now(),
    nights: integer(j, 'nights'),
    rooms: integer(j, 'rooms', fallback: 1),
    adults: integer(j, 'adults', fallback: 2),
    children: integer(j, 'children'),
    currency: strOrNull(j, 'currency'),
    fromTotal: dbl(j, 'fromTotal'),
    roomQuotes: objList(j, 'roomQuotes', RoomQuote.fromJson),
  );
}

/// A food place from `GET /foods/{id}`.
class FoodDetail {
  const FoodDetail({
    required this.id,
    required this.name,
    this.slug,
    this.destinationId,
    this.type,
    this.shortDescription,
    this.description,
    this.slogan,
    this.sloganBy,
    this.provinceId,
    this.address,
    this.latitude,
    this.longitude,
    this.priceRange,
    this.priceFrom,
    this.currency,
    this.openingHours = const {},
    this.phone,
    this.contactEmail,
    this.website,
    this.telegram,
    this.whatsapp,
    this.facebookUrl,
    required this.coverUrl,
    this.averageRating,
    this.reviewCount = 0,
    this.cuisines = const [],
    this.mealsServed = const [],
    this.interestIds = const [],
    this.openNow,
    this.todayHours,
  });

  final String id;
  final String name;
  final String? slug;
  final String? destinationId;

  /// RESTAURANT, CAFE, STREET_FOOD, MARKET, OTHER.
  final String? type;
  final String? shortDescription;
  final String? description;
  final String? slogan;
  final String? sloganBy;
  final String? provinceId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? priceRange;
  final double? priceFrom;
  final String? currency;

  /// `mon`…`sun` → "07:00-22:00" or "closed"; a missing day is shut.
  final Map<String, String> openingHours;

  /// Open at this moment in Cambodia, worked out by the server; null when no
  /// hours are known.
  final bool? openNow;

  /// Today's line: "07:00-22:00" or "closed".
  final String? todayHours;
  final String? phone;
  final String? contactEmail;
  final String? website;
  final String? telegram;
  final String? whatsapp;
  final String? facebookUrl;
  final String coverUrl;
  final double? averageRating;
  final int reviewCount;

  /// Slugs such as `khmer`, `street-food`.
  final List<String> cuisines;

  /// Slugs such as `breakfast`, `dinner`.
  final List<String> mealsServed;
  final List<String> interestIds;

  bool get hasPin => latitude != null && longitude != null;

  factory FoodDetail.fromJson(Json j) => FoodDetail(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    destinationId: strOrNull(j, 'destinationId'),
    type: strOrNull(j, 'type'),
    shortDescription: strOrNull(j, 'shortDescription'),
    description: strOrNull(j, 'description'),
    slogan: strOrNull(j, 'slogan'),
    sloganBy: strOrNull(j, 'sloganBy'),
    provinceId: strOrNull(j, 'provinceId'),
    address: strOrNull(j, 'address'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    priceRange: strOrNull(j, 'priceRange'),
    priceFrom: dbl(j, 'priceFrom'),
    currency: strOrNull(j, 'currency'),
    openingHours: _stringMap(j['openingHours']),
    phone: strOrNull(j, 'phone'),
    contactEmail: strOrNull(j, 'contactEmail'),
    website: strOrNull(j, 'website'),
    telegram: strOrNull(j, 'telegram'),
    whatsapp: strOrNull(j, 'whatsapp'),
    facebookUrl: strOrNull(j, 'facebookUrl'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    averageRating: dbl(j, 'averageRating'),
    reviewCount: integer(j, 'reviewCount'),
    cuisines: strList(j, 'cuisines'),
    mealsServed: strList(j, 'mealsServed'),
    interestIds: strList(j, 'interestIds'),
    openNow: boolOrNull(j, 'openNow'),
    todayHours: strOrNull(j, 'todayHours'),
  );
}

/// An activity from `GET /activities/{id}`: something a traveller does
/// rather than visits, run by someone to contact. Its rating, review count
/// and seal come from its card. No price, duration or hours yet.
class ActivityDetail {
  const ActivityDetail({
    required this.id,
    required this.name,
    this.slug,
    this.destinationId,
    this.type,
    this.shortDescription,
    this.description,
    this.slogan,
    this.sloganBy,
    this.provinceId,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.contactEmail,
    this.website,
    this.telegram,
    this.whatsapp,
    this.facebookUrl,
    required this.coverUrl,
    this.interestIds = const [],
  });

  final String id;
  final String name;
  final String? slug;

  /// The attraction it starts from or belongs to.
  final String? destinationId;

  /// DIVING, KAYAK, BIRD_SANCTUARY, WILDLIFE, HIKING_TREKKING, FISHING,
  /// CAMPING, VIEWPOINT, CRUISE, SHOPPING, OTHER.
  final String? type;
  final String? shortDescription;

  /// May be HTML.
  final String? description;
  final String? slogan;
  final String? sloganBy;
  final String? provinceId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? contactEmail;
  final String? website;
  final String? telegram;
  final String? whatsapp;
  final String? facebookUrl;
  final String coverUrl;

  /// Its interests in the "Activities & Experiences" group: the chips.
  final List<String> interestIds;

  bool get hasPin => latitude != null && longitude != null;

  factory ActivityDetail.fromJson(Json j) => ActivityDetail(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    destinationId: strOrNull(j, 'destinationId'),
    type: strOrNull(j, 'type'),
    shortDescription: strOrNull(j, 'shortDescription'),
    description: strOrNull(j, 'description'),
    slogan: strOrNull(j, 'slogan'),
    sloganBy: strOrNull(j, 'sloganBy'),
    provinceId: strOrNull(j, 'provinceId'),
    address: strOrNull(j, 'address'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
    phone: strOrNull(j, 'phone'),
    contactEmail: strOrNull(j, 'contactEmail'),
    website: strOrNull(j, 'website'),
    telegram: strOrNull(j, 'telegram'),
    whatsapp: strOrNull(j, 'whatsapp'),
    facebookUrl: strOrNull(j, 'facebookUrl'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    interestIds: strList(j, 'interestIds'),
  );
}

/// A corridor from `GET /corridors/{id}` (also inside its itinerary).
class CorridorDetail {
  const CorridorDetail({
    required this.id,
    required this.name,
    this.slug,
    this.shortDescription,
    this.description,
    required this.coverUrl,
    this.durationDays,
    this.durationNights,
    this.stopCount,
    this.totalDistanceKm,
    this.totalDurationMinutes,
    this.estimatedBudgetMin,
    this.estimatedBudgetMax,
    this.expectations = const [],
  });

  final String id;
  final String name;
  final String? slug;
  final String? shortDescription;
  final String? description;
  final String coverUrl;
  final int? durationDays;
  final int? durationNights;
  final int? stopCount;
  final double? totalDistanceKm;
  final int? totalDurationMinutes;
  final double? estimatedBudgetMin;
  final double? estimatedBudgetMax;

  /// "What you expect": short labels in the CMS's order, at most 12; often
  /// none.
  final List<String> expectations;

  factory CorridorDetail.fromJson(Json j) => CorridorDetail(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    shortDescription: strOrNull(j, 'shortDescription'),
    description: strOrNull(j, 'description'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    durationDays: intOrNull(j, 'durationDays'),
    durationNights: intOrNull(j, 'durationNights'),
    stopCount: intOrNull(j, 'stopCount'),
    totalDistanceKm: dbl(j, 'totalDistanceKm'),
    totalDurationMinutes: intOrNull(j, 'totalDurationMinutes'),
    estimatedBudgetMin: dbl(j, 'estimatedBudgetMin'),
    estimatedBudgetMax: dbl(j, 'estimatedBudgetMax'),
    expectations: strList(j, 'expectations'),
  );
}

/// The destination a corridor stop is at, as the itinerary embeds it.
class StopPlace {
  const StopPlace({
    required this.id,
    required this.name,
    this.slug,
    this.shortDescription,
    required this.coverUrl,
    this.provinceName,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? slug;
  final String? shortDescription;
  final String coverUrl;
  final String? provinceName;
  final double? latitude;
  final double? longitude;

  factory StopPlace.fromJson(Json j) => StopPlace(
    id: str(j, 'id'),
    name: str(j, 'name'),
    slug: strOrNull(j, 'slug'),
    shortDescription: strOrNull(j, 'shortDescription'),
    coverUrl: ApiConfig.mediaUrl(strOrNull(j, 'coverUrl')),
    provinceName: strOrNull(j, 'provinceName'),
    latitude: dbl(j, 'latitude'),
    longitude: dbl(j, 'longitude'),
  );
}

class ItineraryStop {
  const ItineraryStop({
    required this.sequence,
    required this.place,
    this.title,
    this.description,
    this.arrivalTime,
    this.departureTime,
    this.recommendedDurationMinutes,
    this.transportType,
    this.distanceFromPreviousKm,
    this.travelTimeFromPreviousMinutes,
    this.routePolyline,
  });

  final int sequence;
  final StopPlace place;
  final String? title;
  final String? description;
  final String? arrivalTime;
  final String? departureTime;
  final int? recommendedDurationMinutes;
  final String? transportType;
  final double? distanceFromPreviousKm;
  final int? travelTimeFromPreviousMinutes;

  /// Google encoded polyline from the previous stop.
  final String? routePolyline;

  factory ItineraryStop.fromJson(Json j) => ItineraryStop(
    sequence: integer(j, 'sequence'),
    place: StopPlace.fromJson(obj(j, 'destination')),
    title: strOrNull(j, 'title'),
    description: strOrNull(j, 'description'),
    arrivalTime: strOrNull(j, 'arrivalTime'),
    departureTime: strOrNull(j, 'departureTime'),
    recommendedDurationMinutes: intOrNull(j, 'recommendedDurationMinutes'),
    transportType: strOrNull(j, 'transportType'),
    distanceFromPreviousKm: dbl(j, 'distanceFromPreviousKm'),
    travelTimeFromPreviousMinutes: intOrNull(j, 'travelTimeFromPreviousMinutes'),
    routePolyline: strOrNull(j, 'routePolyline'),
  );
}

class ItineraryDay {
  const ItineraryDay({required this.dayNumber, this.title, this.description, this.stops = const []});

  final int dayNumber;
  final String? title;
  final String? description;
  final List<ItineraryStop> stops;

  factory ItineraryDay.fromJson(Json j) => ItineraryDay(
    dayNumber: integer(j, 'dayNumber'),
    title: strOrNull(j, 'title'),
    description: strOrNull(j, 'description'),
    stops: objList(j, 'stops', ItineraryStop.fromJson)..sort((a, b) => a.sequence.compareTo(b.sequence)),
  );
}

/// `GET /corridors/{id}/itinerary`: the corridor, its days and stops, and
/// the whole route as one Google encoded polyline.
class CorridorItinerary {
  const CorridorItinerary({required this.corridor, this.days = const [], this.encodedPolyline});

  final CorridorDetail corridor;
  final List<ItineraryDay> days;
  final String? encodedPolyline;

  /// Every stop in order, across the days.
  List<ItineraryStop> get stops => [for (final d in days) ...d.stops];

  factory CorridorItinerary.fromJson(Json j) => CorridorItinerary(
    corridor: CorridorDetail.fromJson(obj(j, 'corridor')),
    days: objList(j, 'days', ItineraryDay.fromJson)..sort((a, b) => a.dayNumber.compareTo(b.dayNumber)),
    encodedPolyline: strOrNull(obj(j, 'route'), 'encodedPolyline'),
  );
}
