/// Central switch between mock data and the real backend.
///
/// While the API is being built the app runs entirely on the JSON files in
/// `assets/mock/`. When the backend is ready:
///   1. set [useMockData] to `false`
///   2. set [baseUrl] to the API host
///   3. check the paths in [ApiEndpoints] match the backend routes
///
/// Both values can also be passed at build time without editing code:
///   flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://api.example.com
class ApiConfig {
  const ApiConfig._();

  static const bool useMockData = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.ams-travel.example.com/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Artificial latency for mock responses so loading states are visible.
  static const Duration mockLatency = Duration(milliseconds: 350);
}

/// Every backend route the app calls, in one place.
class ApiEndpoints {
  const ApiEndpoints._();

  // Content
  static const home = '/home';
  static const regions = '/regions';
  static String region(String slug) => '/regions/$slug';
  static String regionStories(String region) => '/regions/$region/stories';
  static String story(String region, String slug) => '/regions/$region/stories/$slug';
  static String regionReviews(String region) => '/regions/$region/reviews';
  static const destinations = '/destinations';
  static String destination(String region, String slug) => '/regions/$region/destinations/$slug';
  static String destinationReviews(String region, String slug) => '/regions/$region/destinations/$slug/reviews';

  static const myReviews = '/me/reviews';

  static String rooms(String region, String slug) => '/regions/$region/destinations/$slug/rooms';
  static const provinces = '/provinces';
  static String province(String slug) => '/provinces/$slug';
  static const interests = '/interests';
  static String interest(String slug) => '/interests/$slug';
  static const corridors = '/corridors';
  static String corridor(String slug) => '/corridors/$slug';
  static const search = '/search';
  static const planRequests = '/plan-requests';

  // Auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const logout = '/auth/logout';
  static const me = '/auth/me';

  // User data
  static const saved = '/me/saved';
  static const stamps = '/me/stamps';
}
