import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/api_config.dart';
import '../models/json_utils.dart';

/// What Keycloak hands back after sign-in or a refresh.
class KeycloakTokens {
  const KeycloakTokens({required this.accessToken, this.refreshToken, this.idToken, this.expiresAt});

  final String accessToken;
  final String? refreshToken;

  /// Sent back when signing out, so Keycloak ends the right session.
  final String? idToken;
  final DateTime? expiresAt;

  /// True when the access token runs out within [margin].
  bool expiresWithin(Duration margin) => expiresAt != null && DateTime.now().add(margin).isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory KeycloakTokens.fromJson(Map<String, dynamic> j) => KeycloakTokens(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String?,
    idToken: j['idToken'] as String?,
    expiresAt: dateOrNull(j, 'expiresAt'),
  );
}

/// Sign-in, sign-up, the email code and forgot-password all happen on
/// Keycloak's own pages; the app only opens them and keeps the tokens.
abstract class KeycloakClient {
  /// Opens Keycloak's sign-in page. Null when the traveller closes it.
  Future<KeycloakTokens?> signIn();

  /// Opens Keycloak's registration page (then its email-code step). Null
  /// when the traveller closes it.
  Future<KeycloakTokens?> register();

  /// Trades the refresh token for a new access token.
  Future<KeycloakTokens> refresh(KeycloakTokens current);

  /// Ends the Keycloak session in the browser.
  Future<void> signOut(KeycloakTokens current);
}

/// [KeycloakClient] through AppAuth: authorization code with PKCE (S256) in
/// the system browser, client `amstravel-mobile`, redirect `amstravel://callback`.
class AppAuthKeycloak implements KeycloakClient {
  AppAuthKeycloak([FlutterAppAuth? appAuth]) : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  static const _issuer = ApiConfig.issuer;
  static const _openid = '$_issuer/protocol/openid-connect';

  /// The endpoints spelled out, so registration can swap the authorize page
  /// for Keycloak's registration page with the same parameters.
  static const _signInConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: '$_openid/auth',
    tokenEndpoint: '$_openid/token',
    endSessionEndpoint: '$_openid/logout',
  );
  static const _registerConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: '$_openid/registrations',
    tokenEndpoint: '$_openid/token',
    endSessionEndpoint: '$_openid/logout',
  );

  Future<KeycloakTokens?> _authorize(AuthorizationServiceConfiguration config) async {
    // The device clock is logged because AppAuth rejects an ID token issued
    // more than 10 minutes from it.
    final now = DateTime.now();
    authLog('authorize start: ${config.authorizationEndpoint} '
        'deviceClockUtc=${now.toUtc().toIso8601String()} tz=${now.timeZoneName}');
    try {
      final res = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          ApiConfig.clientId,
          ApiConfig.redirectUri,
          serviceConfiguration: config,
          scopes: ApiConfig.scopes,
        ),
      );
      authLog('authorize ok: accessToken=${res.accessToken != null} refreshToken=${res.refreshToken != null} '
          'idToken=${res.idToken != null} expires=${res.accessTokenExpirationDateTime?.toUtc().toIso8601String()}');
      return _tokens(res.accessToken, res.refreshToken, res.idToken, res.accessTokenExpirationDateTime);
    } on FlutterAppAuthUserCancelledException catch (e, st) {
      authError('authorize cancelled', e, st);
      return null;
    } catch (e, st) {
      authError('authorize failed', e, st);
      rethrow;
    }
  }

  static KeycloakTokens _tokens(String? access, String? refresh, String? id, DateTime? expires, [KeycloakTokens? old]) {
    if (access == null || access.isEmpty) throw StateError('Keycloak returned no access token');
    return KeycloakTokens(
      accessToken: access,
      refreshToken: refresh ?? old?.refreshToken,
      idToken: id ?? old?.idToken,
      expiresAt: expires,
    );
  }

  @override
  Future<KeycloakTokens?> signIn() => _authorize(_signInConfig);

  @override
  Future<KeycloakTokens?> register() => _authorize(_registerConfig);

  @override
  Future<KeycloakTokens> refresh(KeycloakTokens current) async {
    try {
      final res = await _appAuth.token(
        TokenRequest(
          ApiConfig.clientId,
          ApiConfig.redirectUri,
          serviceConfiguration: _signInConfig,
          refreshToken: current.refreshToken,
          grantType: GrantType.refreshToken,
          scopes: ApiConfig.scopes,
        ),
      );
      authLog('refresh ok: expires=${res.accessTokenExpirationDateTime?.toUtc().toIso8601String()}');
      return _tokens(res.accessToken, res.refreshToken, res.idToken, res.accessTokenExpirationDateTime, current);
    } catch (e, st) {
      authError('refresh failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> signOut(KeycloakTokens current) async {
    await _appAuth.endSession(
      EndSessionRequest(
        idTokenHint: current.idToken,
        postLogoutRedirectUrl: ApiConfig.redirectUri,
        serviceConfiguration: _signInConfig,
      ),
    );
  }
}

/// Sign-in diagnostics, in logcat under the `flutter` tag. Never logs tokens.
void authLog(String message) => debugPrint('[auth] $message', wrapWidth: 900);

/// Logs [error] in full: for AppAuth errors the platform code, the OAuth
/// error and its description, and the root cause.
void authError(String what, Object error, [StackTrace? stack]) {
  final buf = StringBuffer('$what: ${error.runtimeType}');
  if (error is PlatformException) {
    buf.write(' code=${error.code} message=${error.message}');
  }
  if (error is FlutterAppAuthUserCancelledException) {
    buf.write('\n${error.platformErrorDetails}');
  } else if (error is FlutterAppAuthPlatformException) {
    buf.write('\n${error.platformErrorDetails}');
  } else if (error is PlatformException) {
    buf.write(' details=${error.details}');
  } else {
    buf.write(' $error');
  }
  if (stack != null) buf.write('\n$stack');
  authLog(buf.toString());
}

/// Where the tokens live between launches.
abstract class TokenStore {
  Future<KeycloakTokens?> read();
  Future<void> write(KeycloakTokens tokens);
  Future<void> clear();
}

/// The device keychain / keystore.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'ams-travel:keycloak-tokens';
  final FlutterSecureStorage _storage;

  @override
  Future<KeycloakTokens?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == null ? null : KeycloakTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      authError('token store read failed', e, st);
      return null;
    }
  }

  @override
  Future<void> write(KeycloakTokens tokens) => _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Keeps the tokens in memory only. For tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);

  KeycloakTokens? _tokens;

  @override
  Future<KeycloakTokens?> read() async => _tokens;

  @override
  Future<void> write(KeycloakTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
