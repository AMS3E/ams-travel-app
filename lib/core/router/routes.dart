/// URL paths — the same shape as the website so links can be shared between
/// the two (and deep links work later).
class Routes {
  const Routes._();

  static const welcome = '/welcome';
  static const interests = '/your-interests';
  static const popular = '/popular';
  static const popularSearch = '/popular/search';
  static const badges = '/badges';
  static const account = '/account';
  static const help = '/help';
  static const terms = '/terms';
  static const preferences = '/preferences';
  static const language = '/preferences/language';
  static const currency = '/preferences/currency';
  static const units = '/preferences/units';
  static const notifications = '/preferences/notifications';
  static const myReviews = '/my-reviews';
  static const folders = '/folders';
  static String folder(String name) => '/folders/${Uri.encodeComponent(name)}';
  static String achievement(String badge) => '/badges/$badge';

  static const exploreInterests = '/interests/explore';
  static const exploreProvinces = '/provinces/explore';
  static const home = '/';
  static const explore = '/explore';
  static const map = '/map';
  static const saved = '/saved';
  static const profile = '/profile';
  static const search = '/search';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static String exploreTab(String tab) => '/explore?tab=$tab';
  static String region(String slug) => '/regions/$slug';
  static String destination(String region, String slug) => '/regions/$region/$slug';
  static String review(String region, String slug) => '/regions/$region/$slug/review';
  static String rooms(String region, String slug) => '/regions/$region/$slug/rooms';
  static String room(String region, String slug, String roomId) => '/regions/$region/$slug/rooms/$roomId';
  static String story(String region, String slug) => '/regions/$region/stories/$slug';
  static String province(String slug) => '/provinces/$slug';
  static String interest(String slug) => '/interests/$slug';
  static String corridor(String slug) => '/corridors/$slug';
  static String mapFocus(String destinationKey) => '/map?place=${Uri.encodeComponent(destinationKey)}';
  static String mapCorridor(String slug) => '/map?corridor=${Uri.encodeComponent(slug)}';
}
