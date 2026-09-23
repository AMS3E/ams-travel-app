import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String identifier, required String password});
  Future<AuthSession> register({required String username, required String email, required String password});
  Future<void> forgotPassword(String email);
  Future<void> logout();
}

/// Accepts any well-formed credentials so every screen can be exercised
/// before the backend exists.
class MockAuthRepository implements AuthRepository {
  Future<T> _delay<T>(T v) => Future.delayed(const Duration(milliseconds: 700), () => v);

  @override
  Future<AuthSession> login({required String identifier, required String password}) {
    final isEmail = identifier.contains('@');
    return _delay(
      AuthSession(
        token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
        user: AppUser(
          id: 'mock-user',
          username: isEmail ? identifier.split('@').first : identifier,
          email: isEmail ? identifier : '$identifier@example.com',
          firstName: (isEmail ? identifier.split('@').first : identifier),
          location: 'Phnom Penh, Cambodia',
          joinedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<AuthSession> register({required String username, required String email, required String password}) => _delay(
    AuthSession(
      token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
      user: AppUser(
        id: 'mock-user',
        username: username,
        email: email,
        location: 'Phnom Penh, Cambodia',
        joinedAt: DateTime.now(),
      ),
    ),
  );

  @override
  Future<void> forgotPassword(String email) => _delay(null);

  @override
  Future<void> logout() async {}
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> login({required String identifier, required String password}) async {
    final body = await _api.post(ApiEndpoints.login, body: {'identifier': identifier, 'password': password});
    return AuthSession.fromJson(Json.from(body as Map));
  }

  @override
  Future<AuthSession> register({required String username, required String email, required String password}) async {
    final body = await _api.post(
      ApiEndpoints.register,
      body: {'username': username, 'email': email, 'password': password},
    );
    return AuthSession.fromJson(Json.from(body as Map));
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _api.post(ApiEndpoints.forgotPassword, body: {'email': email});
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } on ApiException {
      // Logging out locally matters more than telling the server.
    }
  }
}
