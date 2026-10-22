/// Where the AMS Travel API lives. See `assets/docs/mobile/README.md`.
///
/// Both values can be overridden at build time:
///   flutter run --dart-define=API_ORIGIN=https://staging.example.com
class ApiConfig {
  const ApiConfig._();

  /// The server origin. Picture links are paths and go after this.
  static const String origin = String.fromEnvironment('API_ORIGIN', defaultValue: 'https://api.travel.ams.com.kh');

  static const String baseUrl = '$origin/api/v1';

  /// Keycloak realm for travellers, signed in through AppAuth.
  static const String issuer = String.fromEnvironment(
    'AUTH_ISSUER',
    defaultValue: 'https://auth.travel.ams.com.kh/realms/amstravel',
  );
  static const String clientId = 'amstravel-mobile';
  static const String redirectUri = 'amstravel://callback';
  static const List<String> scopes = ['openid', 'profile', 'email', 'offline_access'];

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// A full link for a picture path such as `/api/v1/media/files/...`.
  /// Empty when there is no picture, which [AppImage] draws as a placeholder.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$origin${path.startsWith('/') ? '' : '/'}$path';
  }
}
