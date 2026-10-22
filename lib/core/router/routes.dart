import '../../data/api/catalog.dart';
import '../utils/geo.dart';

/// URL paths — the same shape as the website so links can be shared between
/// the two (and deep links work later).
class Routes {
  const Routes._();

  static const welcome = '/welcome';
  static const popular = '/popular';
  static const popularSearch = '/popular/search';
  static const badges = '/badges';
  static const account = '/account';
  static const notificationsPage = '/notifications';
  static const editProfile = '/profile/edit';

  /// The account form opened at one field: `name`, `phone` or `province`.
  static String accountField(String field) => '$account?field=$field';

  /// The profile form with the photo picker opened at once.
  static const pickProfilePhoto = '$editProfile?pick=photo';
  static const help = '/help';
  static const terms = '/terms';
  static const preferences = '/preferences';
  static const language = '/preferences/language';
  static const currency = '/preferences/currency';
  static const units = '/preferences/units';
  static const notifications = '/preferences/notifications';
  static const myReviews = '/my-reviews';
  static String myReview(String id) => '/my-reviews/${Uri.encodeComponent(id)}';
  static String folder(String name) => '/folders/${Uri.encodeComponent(name)}';
  static String badgeTiers(String badge) => '/badges/$badge';

  /// A badge's page; [earned] (a `GET /badges/me/earned` row id) picks one
  /// particular earn, such as a past season's.
  static String achievement(String badge, {String? earned}) =>
      '/badges/$badge/achievement${earned == null ? '' : '?earned=${Uri.encodeComponent(earned)}'}';
  static const pastSeasons = '/badges/seasons';
  static String seasonBadges(String seasonId) => '/badges/seasons/$seasonId';

  static const exploreInterests = '/interests/explore';
  static const exploreProvinces = '/provinces/explore';
  static const exploreRegions = '/regions/explore';
  static const exploreCorridors = '/corridors';
  static const home = '/';
  static const map = '/map';
  static const saved = '/saved';
  static const profile = '/profile';
  static const search = '/search';

  // Pages keyed by the API's ids.
  static String region(String id) => '/regions/$id';

  /// An attraction (`GET /destinations/{id}`).
  static String place(String id) => '/places/$id';
  static String stay(String id) => '/stays/$id';
  static String stayRooms(String stayId) => '/stays/$stayId/rooms';
  static String stayRoom(String stayId, String roomId) => '/stays/$stayId/rooms/$roomId';
  static String food(String id) => '/foods/$id';
  static String activity(String id) => '/activities/$id';

  /// The check-in scanner. Any place's code may be scanned there: the result
  /// is for the place the code belongs to.
  static const checkIn = '/check-in';
  static String corridor(String id) => '/corridors/$id';
  static String province(String id) => '/provinces/$id';
  static String provincePlaces(String id) => '/provinces/$id/places';

  /// One of the six interest groups, by its slugified name ("attraction-sites").
  static String interest(String groupName) => '/interests/${slugify(groupName)}';

  /// The reviews of a place, a stay, a food place, an activity or a corridor.
  static String reviews(CardType type, String id) => '/reviews/${type.name}/$id';
  static String writeReview(CardType type, String id) => '/reviews/${type.name}/$id/new';

  /// The page a card opens.
  static String card(PlaceCard c) => target(c.type, c.id);

  /// The page for a kind of thing and its id.
  static String target(CardType type, String id) => switch (type) {
    CardType.destination => place(id),
    CardType.stay => stay(id),
    CardType.food => food(id),
    CardType.activity => activity(id),
    CardType.corridor => corridor(id),
  };

  static String mapFocus(String destinationId) => '/map?place=${Uri.encodeComponent(destinationId)}';
  static String mapCorridor(String corridorId) => '/map?corridor=${Uri.encodeComponent(corridorId)}';
}
