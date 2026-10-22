import '../../core/config/api_config.dart';
import '../../core/utils/dates.dart';
import '../models/json_utils.dart';
import 'catalog.dart';
import 'details.dart';

/// Who the reviewer travelled with.
enum VisitType { business, couples, family, friends, solo }

VisitType? _visitType(String? code) {
  for (final v in VisitType.values) {
    if (v.name.toUpperCase() == code) return v;
  }
  return null;
}

/// A review from `GET /reviews`, `GET /reviews/me` or `GET /reviews/{id}`.
class TravelReview {
  const TravelReview({
    required this.id,
    this.userId,
    required this.authorName,
    this.authorAvatarUrl = '',
    required this.targetType,
    required this.targetId,
    required this.rating,
    this.title,
    this.content,
    this.visitType,
    this.visitedOn,
    this.status,
    this.photos = const [],
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String authorName;
  final String authorAvatarUrl;
  final CardType targetType;
  final String targetId;
  final int rating;
  final String? title;
  final String? content;
  final VisitType? visitType;

  /// The month of the visit, "YYYY-MM".
  final String? visitedOn;

  /// PENDING, PUBLISHED, HIDDEN, REJECTED, DELETED.
  final String? status;
  final List<MediaItem> photos;
  final DateTime createdAt;

  /// Waiting for a moderator.
  bool get isPending => status == 'PENDING';

  /// Not shown to other travellers: waiting, rejected or hidden.
  bool get isUnpublished => isPending || status == 'REJECTED' || status == 'HIDDEN';

  /// [visitedOn] as the first day of that month.
  DateTime? get visitedMonth {
    final v = visitedOn;
    if (v == null || v.length < 7) return null;
    return DateTime.tryParse('${v.substring(0, 7)}-01');
  }

  factory TravelReview.fromJson(Json j) => TravelReview(
    id: str(j, 'id'),
    userId: strOrNull(j, 'userId'),
    authorName: str(j, 'authorName'),
    authorAvatarUrl: ApiConfig.mediaUrl(strOrNull(j, 'authorAvatarUrl')),
    targetType: CardType.parse(str(j, 'targetType')),
    targetId: str(j, 'targetId'),
    rating: integer(j, 'rating'),
    title: strOrNull(j, 'title'),
    content: strOrNull(j, 'content'),
    visitType: _visitType(strOrNull(j, 'visitType')),
    visitedOn: strOrNull(j, 'visitedOn'),
    status: strOrNull(j, 'status'),
    photos: objList(j, 'photos', MediaItem.fromJson),
    createdAt: dateOrNull(j, 'createdAt') ?? DateTime.now(),
  );
}

/// What a review sends: one `POST /reviews` (or `PUT /reviews/{id}`).
class ReviewDraft {
  /// The longest title and text the API takes.
  static const titleMax = 200;
  static const contentMax = 5000;

  const ReviewDraft({
    required this.rating,
    this.title,
    this.content,
    this.visitType,
    this.visitedOn,
    this.photoKeys = const [],
  });

  /// 1 to 5.
  final int rating;

  /// At most 200 characters.
  final String? title;

  /// At most 5000 characters.
  final String? content;
  final VisitType? visitType;

  /// Only the year and month count.
  final DateTime? visitedOn;

  /// From `POST /media/files` with type `review`.
  final List<String> photoKeys;

  Json toJson() => {
    'rating': rating,
    if (title != null && title!.isNotEmpty) 'title': title,
    if (content != null && content!.isNotEmpty) 'content': content,
    if (visitType != null) 'visitType': visitType!.name.toUpperCase(),
    if (visitedOn != null) 'visitedOn': Dates.isoMonth(visitedOn!),
    'photoKeys': photoKeys,
  };
}

/// `GET /ratings/summary`: average, count and how many of each star.
class RatingSummary {
  const RatingSummary({required this.targetId, this.average, this.count = 0, this.stars = const {}});

  final String targetId;
  final double? average;
  final int count;

  /// Star (1–5) → how many gave it.
  final Map<int, int> stars;

  /// The average to show: none until someone has rated.
  double? get shownAverage => count > 0 ? average : null;

  factory RatingSummary.fromJson(Json j) => RatingSummary(
    targetId: str(j, 'targetId'),
    average: dbl(j, 'average'),
    count: integer(j, 'count'),
    stars: {
      for (final e in (j['stars'] as Map? ?? const {}).entries)
        if (int.tryParse(e.key.toString()) != null) int.parse(e.key.toString()): (e.value as num?)?.toInt() ?? 0,
    },
  );
}

/// The signed-in traveller, from `GET /users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarKey,
    this.avatarUrl = '',
    this.phone,
    this.homeProvinceId,
    this.homeProvinceName,
    this.profileCompletion,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarKey;
  final String avatarUrl;
  final String? phone;
  final String? homeProvinceId;
  final String? homeProvinceName;

  /// 0–100: name, email, phone, picture and home province count 20 each.
  final int? profileCompletion;

  /// The joined date.
  final DateTime? createdAt;

  /// The name to show: the full name, or the email's first part.
  String get displayName {
    final n = fullName?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  String get initials => displayName.isEmpty ? '?' : String.fromCharCode(displayName.runes.first).toUpperCase();

  factory UserProfile.fromJson(Json j) => UserProfile(
    id: str(j, 'id'),
    email: str(j, 'email'),
    fullName: strOrNull(j, 'fullName'),
    avatarKey: strOrNull(j, 'avatarKey'),
    avatarUrl: ApiConfig.mediaUrl(strOrNull(j, 'avatarUrl')),
    phone: strOrNull(j, 'phone'),
    homeProvinceId: strOrNull(j, 'homeProvinceId'),
    homeProvinceName: strOrNull(j, 'homeProvinceName'),
    profileCompletion: intOrNull(j, 'profileCompletion'),
    createdAt: dateOrNull(j, 'createdAt'),
  );

  Json toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'avatarKey': avatarKey,
    'avatarUrl': avatarUrl,
    'phone': phone,
    'homeProvinceId': homeProvinceId,
    'homeProvinceName': homeProvinceName,
    'profileCompletion': profileCompletion,
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// `GET /preferences/me`.
class UserPreferences {
  const UserPreferences({
    this.preferredLanguage,
    this.preferredCurrency,
    this.preferredRegionId,
    this.notificationEmail = true,
    this.notificationPush = true,
    this.theme,
    this.distanceUnit,
  });

  /// "en" or "km".
  final String? preferredLanguage;

  /// "USD" or "KHR".
  final String? preferredCurrency;
  final String? preferredRegionId;
  final bool notificationEmail;
  final bool notificationPush;
  final String? theme;

  /// "KM" or "MI".
  final String? distanceUnit;

  UserPreferences copyWith({
    String? preferredLanguage,
    String? preferredCurrency,
    bool? notificationEmail,
    bool? notificationPush,
    String? distanceUnit,
  }) => UserPreferences(
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    preferredRegionId: preferredRegionId,
    notificationEmail: notificationEmail ?? this.notificationEmail,
    notificationPush: notificationPush ?? this.notificationPush,
    theme: theme,
    distanceUnit: distanceUnit ?? this.distanceUnit,
  );

  factory UserPreferences.fromJson(Json j) => UserPreferences(
    preferredLanguage: strOrNull(j, 'preferredLanguage'),
    preferredCurrency: strOrNull(j, 'preferredCurrency'),
    preferredRegionId: strOrNull(j, 'preferredRegionId'),
    notificationEmail: boolOrNull(j, 'notificationEmail') ?? true,
    notificationPush: boolOrNull(j, 'notificationPush') ?? true,
    theme: strOrNull(j, 'theme'),
    distanceUnit: strOrNull(j, 'distanceUnit'),
  );

  Json toJson() => {
    'preferredLanguage': preferredLanguage,
    'preferredCurrency': preferredCurrency,
    'preferredRegionId': preferredRegionId,
    'notificationEmail': notificationEmail,
    'notificationPush': notificationPush,
    'theme': theme,
    'distanceUnit': distanceUnit,
  };
}

/// What can be a favourite: the five kinds of card, and regions and provinces.
enum FavoriteType {
  destination('DESTINATION'),
  stay('STAY'),
  food('FOOD'),
  activity('ACTIVITY'),
  corridor('CORRIDOR'),
  region('REGION'),
  province('PROVINCE');

  const FavoriteType(this.code);
  final String code;

  static FavoriteType parse(String code) =>
      values.firstWhere((t) => t.code == code, orElse: () => FavoriteType.destination);

  /// The same kind as a card type.
  static FavoriteType of(CardType type) => parse(type.code);

  /// The card type, for the five kinds that are cards; null for regions and provinces.
  CardType? get cardType => switch (this) {
    destination => CardType.destination,
    stay => CardType.stay,
    food => CardType.food,
    activity => CardType.activity,
    corridor => CardType.corridor,
    region || province => null,
  };
}

/// `GET /favorites`: what is saved, by kind and id.
class Favorite {
  const Favorite({required this.targetType, required this.targetId, this.createdAt});

  final FavoriteType targetType;
  final String targetId;
  final DateTime? createdAt;

  factory Favorite.fromJson(Json j) => Favorite(
    targetType: FavoriteType.parse(str(j, 'targetType')),
    targetId: str(j, 'targetId'),
    createdAt: dateOrNull(j, 'createdAt'),
  );
}

/// `GET /notifications`.
class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? body;

  /// PUBLISH_APPROVED, PUBLISH_REJECTED, PUBLISH_CHANGES_REQUESTED, BADGE_EARNED.
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  InboxNotification read() =>
      InboxNotification(id: id, title: title, body: body, type: type, data: data, isRead: true, createdAt: createdAt);

  factory InboxNotification.fromJson(Json j) => InboxNotification(
    id: str(j, 'id'),
    title: str(j, 'title'),
    body: strOrNull(j, 'body'),
    type: str(j, 'type'),
    data: obj(j, 'data'),
    isRead: boolean(j, 'isRead'),
    createdAt: dateOrNull(j, 'createdAt') ?? DateTime.now(),
  );
}

/// A badge level. The design calls GOLDEN "Gold".
enum BadgeLevel { silver, golden, platinum }

BadgeLevel? _level(String? code) {
  for (final l in BadgeLevel.values) {
    if (l.name.toUpperCase() == code) return l;
  }
  return null;
}

/// What a badge counts: BROWSES, REVIEWS or STAMPS (the three ladders since
/// the POINTS one was retired on 2026-10-20), or DESTINATION_STAMPS.
typedef BadgeType = String;

/// A badge definition from `GET /badges`.
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.iconKey,
    required this.type,
    this.level,
    required this.threshold,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? iconKey;
  final BadgeType type;
  final BadgeLevel? level;
  final int threshold;

  factory BadgeDefinition.fromJson(Json j) => BadgeDefinition(
    id: str(j, 'id'),
    code: str(j, 'code'),
    name: str(j, 'name'),
    description: strOrNull(j, 'description'),
    iconKey: strOrNull(j, 'iconKey'),
    type: str(j, 'type'),
    level: _level(strOrNull(j, 'level')),
    threshold: integer(j, 'threshold'),
  );
}

/// A badge the traveller holds or is working towards.
class UserBadge {
  const UserBadge({
    required this.id,
    required this.badgeId,
    required this.code,
    required this.name,
    this.iconKey,
    required this.type,
    this.level,
    this.progress = 0,
    this.threshold = 0,
    this.seasonId,
    this.seasonName,
    this.holderName,
    this.earnedAt,
    this.shareUrl,
  });

  final String id;
  final String badgeId;
  final String code;
  final String name;
  final String? iconKey;
  final BadgeType type;
  final BadgeLevel? level;
  final int progress;
  final int threshold;
  final String? seasonId;
  final String? seasonName;
  final String? holderName;
  final DateTime? earnedAt;

  /// A public web page for the badge, with the tags Facebook reads; null
  /// until earned.
  final String? shareUrl;

  bool get earned => earnedAt != null;

  /// Whether this row is the traveller's progress on [d]. The API sends the
  /// definition's id, but some rows only match on its code.
  bool isFor(BadgeDefinition d) => badgeId == d.id || code == d.code;

  factory UserBadge.fromJson(Json j) => UserBadge(
    id: str(j, 'id'),
    badgeId: str(j, 'badgeId'),
    code: str(j, 'code'),
    name: str(j, 'name'),
    iconKey: strOrNull(j, 'iconKey'),
    type: str(j, 'type'),
    level: _level(strOrNull(j, 'level')),
    progress: integer(j, 'progress'),
    threshold: integer(j, 'threshold'),
    seasonId: strOrNull(j, 'seasonId'),
    seasonName: strOrNull(j, 'seasonName'),
    holderName: strOrNull(j, 'holderName'),
    earnedAt: dateOrNull(j, 'earnedAt'),
    shareUrl: strOrNull(j, 'shareUrl'),
  );
}

/// One track of badge progress: how far along, the level reached and next.
class BadgeTrack {
  const BadgeTrack({
    required this.type,
    this.count = 0,
    this.level,
    this.nextLevel,
    this.remaining,
    this.thresholds = const {},
  });

  final BadgeType type;
  final int count;
  final BadgeLevel? level;
  final BadgeLevel? nextLevel;
  final int? remaining;

  /// Level → threshold.
  final Map<BadgeLevel, int> thresholds;

  /// The count the next level needs; null at the top.
  int? get nextTarget => nextLevel == null ? null : thresholds[nextLevel];

  factory BadgeTrack.fromJson(Json j) => BadgeTrack(
    type: str(j, 'type'),
    count: integer(j, 'count'),
    level: _level(strOrNull(j, 'level')),
    nextLevel: _level(strOrNull(j, 'nextLevel')),
    remaining: intOrNull(j, 'remaining'),
    thresholds: {
      for (final e in (j['thresholds'] as Map? ?? const {}).entries)
        if (_level(e.key.toString()) != null) _level(e.key.toString())!: (e.value as num?)?.toInt() ?? 0,
    },
  );
}

/// `GET /badges/me/progress`, also what a browse answers.
class BadgeProgress {
  const BadgeProgress({
    this.seasonId,
    this.seasonName,
    this.tracks = const [],
    this.badges = const [],
    this.earned = const [],
    this.percentile,
  });

  final String? seasonId;
  final String? seasonName;
  final List<BadgeTrack> tracks;
  final List<UserBadge> badges;
  final List<UserBadge> earned;

  /// Where the traveller stands this season: 5 means the top 5%. Null with
  /// no progress this season.
  final int? percentile;

  BadgeTrack? track(BadgeType type) {
    for (final t in tracks) {
      if (t.type == type) return t;
    }
    return null;
  }

  factory BadgeProgress.fromJson(Json j) => BadgeProgress(
    seasonId: strOrNull(j, 'seasonId'),
    seasonName: strOrNull(j, 'seasonName'),
    tracks: objList(j, 'tracks', BadgeTrack.fromJson),
    badges: objList(j, 'badges', UserBadge.fromJson),
    earned: objList(j, 'earned', UserBadge.fromJson),
    percentile: intOrNull(j, 'percentile'),
  );
}

/// `GET /seasons/current`.
class Season {
  const Season({required this.id, required this.name, this.type, this.startsOn, this.endsOn, this.status});

  final String id;
  final String name;

  /// HIGH_SEASON or GREEN_SEASON.
  final String? type;
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// UPCOMING, ACTIVE, COMPLETED.
  final String? status;

  bool get isUpcoming => status == 'UPCOMING';
  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';

  factory Season.fromJson(Json j) => Season(
    id: str(j, 'id'),
    name: str(j, 'name'),
    type: strOrNull(j, 'type'),
    startsOn: dateOrNull(j, 'startsOn'),
    endsOn: dateOrNull(j, 'endsOn'),
    status: strOrNull(j, 'status'),
  );
}

/// `GET /seasons/me/history`: one season's totals.
class SeasonProgress {
  const SeasonProgress({
    required this.seasonId,
    required this.seasonName,
    this.seasonType,
    this.seasonStatus,
    this.points = 0,
    this.ratingCount = 0,
    this.reviewCount = 0,
    this.ratedPlaceCount = 0,
    this.reviewedPlaceCount = 0,
    this.startedAt,
    this.updatedAt,
  });

  final String seasonId;
  final String seasonName;

  /// HIGH_SEASON or GREEN_SEASON.
  final String? seasonType;

  /// UPCOMING, ACTIVE, COMPLETED.
  final String? seasonStatus;
  final int points;
  final int ratingCount;
  final int reviewCount;

  /// Different places rated and reviewed (`uniqueRatedTargetCount`,
  /// `uniqueReviewedTargetCount`).
  final int ratedPlaceCount;
  final int reviewedPlaceCount;

  /// The traveller's first and latest activity in the season.
  final DateTime? startedAt;
  final DateTime? updatedAt;

  bool get past => seasonStatus == 'COMPLETED';

  factory SeasonProgress.fromJson(Json j) => SeasonProgress(
    seasonId: str(j, 'seasonId'),
    seasonName: str(j, 'seasonName'),
    seasonType: strOrNull(j, 'seasonType'),
    seasonStatus: strOrNull(j, 'seasonStatus'),
    points: integer(j, 'points'),
    ratingCount: integer(j, 'ratingCount'),
    reviewCount: integer(j, 'reviewCount'),
    ratedPlaceCount: integer(j, 'uniqueRatedTargetCount'),
    reviewedPlaceCount: integer(j, 'uniqueReviewedTargetCount'),
    startedAt: dateOrNull(j, 'startedAt'),
    updatedAt: dateOrNull(j, 'updatedAt'),
  );
}

/// How a check-in went (`POST /stamps`).
enum CheckInOutcome {
  collected('COLLECTED'),

  /// One stamp per place per season: this one is already in.
  alreadyCollected('ALREADY_COLLECTED'),

  /// The phone is further from the place than its radius.
  tooFar('TOO_FAR'),

  /// The print is unknown, withdrawn or retired.
  invalidCode('INVALID_CODE');

  const CheckInOutcome(this.code);
  final String code;

  static CheckInOutcome? tryParse(String? code) => values.where((o) => o.code == code).firstOrNull;
}

/// What a check-in answers, and the rows of `GET /stamps/me`. The place is
/// the one the scanned code belongs to: [targetType] and [destinationId],
/// whatever page the scanner was opened from.
class Stamp {
  const Stamp({
    this.id,
    this.targetType = CardType.destination,
    required this.destinationId,
    this.collectedAt,
    this.source,
    this.outcome,
    this.distanceMeters,
    this.radiusMeters,
    this.badgesEarned = const [],
  });

  final String? id;

  /// An attraction, stay, food place or activity.
  final CardType targetType;

  /// The id of that place, whatever its kind.
  final String destinationId;
  final DateTime? collectedAt;

  /// QR (or GPS, for stamps from before codes).
  final String? source;

  /// Null on the rows of `GET /stamps/me`.
  final CheckInOutcome? outcome;
  final int? distanceMeters;
  final int? radiusMeters;
  final List<UserBadge> badgesEarned;

  /// The place is known: every outcome but an unknown code names it.
  bool get hasPlace => outcome != CheckInOutcome.invalidCode && destinationId.isNotEmpty;

  factory Stamp.fromJson(Json j) => Stamp(
    id: strOrNull(j, 'id'),
    targetType: CardType.parse(str(j, 'targetType')),
    destinationId: str(j, 'destinationId'),
    collectedAt: dateOrNull(j, 'collectedAt'),
    source: strOrNull(j, 'source'),
    outcome: CheckInOutcome.tryParse(strOrNull(j, 'outcome')),
    distanceMeters: intOrNull(j, 'distanceMeters'),
    radiusMeters: intOrNull(j, 'radiusMeters'),
    badgesEarned: objList(j, 'badgesEarned', UserBadge.fromJson),
  );
}

/// A row of `GET /points/me`.
class PointEntry {
  const PointEntry({
    required this.id,
    this.targetType,
    this.targetId,
    this.sourceType,
    required this.points,
    this.createdAt,
  });

  final String id;
  final String? targetType;
  final String? targetId;

  /// RATING or REVIEW.
  final String? sourceType;
  final int points;
  final DateTime? createdAt;

  factory PointEntry.fromJson(Json j) => PointEntry(
    id: str(j, 'id'),
    targetType: strOrNull(j, 'targetType'),
    targetId: strOrNull(j, 'targetId'),
    sourceType: strOrNull(j, 'sourceType'),
    points: integer(j, 'points'),
    createdAt: dateOrNull(j, 'createdAt'),
  );
}
