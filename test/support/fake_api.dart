import 'dart:io';
import 'dart:typed_data';

import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/data/auth/keycloak.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [AmsApi] answering from `test/fixtures/api/`: answers saved from the
/// real server. See [FixtureAdapter] for how a call finds its file.
AmsApi fakeAmsApi({TokenSource tokens = const GuestTokens()}) =>
    AmsApi(ApiClient(tokens: tokens, adapter: FixtureAdapter()));

/// A session for tests: signed in or not, Keycloak never opened.
Future<AuthProvider> fakeAuth(SharedPreferences prefs, {bool signedIn = false}) async {
  final store = MemoryTokenStore(
    signedIn ? KeycloakTokens(accessToken: 'test-token', refreshToken: 'test-refresh', expiresAt: DateTime(2100)) : null,
  );
  final api = fakeAmsApi();
  final auth = AuthProvider(keycloak: FakeKeycloak(), store: store, api: api, prefs: prefs);
  api.client.tokens = auth;
  await auth.restore();
  return auth;
}

/// Signs in at once with a test token.
class FakeKeycloak implements KeycloakClient {
  static final tokens = KeycloakTokens(accessToken: 'test-token', refreshToken: 'test-refresh', expiresAt: DateTime(2100));

  @override
  Future<KeycloakTokens?> signIn() async => tokens;

  @override
  Future<KeycloakTokens?> register() async => tokens;

  @override
  Future<KeycloakTokens> refresh(KeycloakTokens current) async => tokens;

  @override
  Future<void> signOut(KeycloakTokens current) async {}
}

/// Finds the fixture for a call from its path: `/search/cards` reads
/// `search_cards.json`, `/destinations/<id>` reads `destinations_<id>.json`.
/// A `type`, `kind` or `seasonId` parameter is tried first as a suffix:
/// `/search?type=CORRIDOR` reads `search@corridor.json` before `search.json`;
/// with `near=` too, `search@stay+near.json` comes first;
/// `/badges/me/progress?seasonId=<id>` reads `badges_me_progress@<id>.json`.
/// Writes (POST, PUT, DELETE) answer `<path>.<method>.json` when present,
/// otherwise an empty success. A call with no fixture answers 404.
class FixtureAdapter implements HttpClientAdapter {
  static const dir = 'test/fixtures/api';

  /// Every request seen, newest last, for tests that check what was sent.
  final List<RequestOptions> requests = [];

  static List<String> candidates(RequestOptions o) {
    final base = o.path.replaceFirst(RegExp('^/'), '').replaceAll('/', '_');
    final method = o.method.toUpperCase();
    if (method != 'GET') return ['$base.${method.toLowerCase()}'];
    final q = o.queryParameters;
    final variant = (q['type'] ?? q['kind'] ?? q['seasonId'])?.toString().toLowerCase();
    return [
      if (variant != null && q['near'] != null) '$base@$variant+near',
      if (variant != null) '$base@$variant',
      base,
    ];
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final name in candidates(options)) {
      final file = File('$dir/$name.json');
      if (file.existsSync()) return ResponseBody.fromString(file.readAsStringSync(), 200, headers: _json);
    }
    if (options.method.toUpperCase() != 'GET') return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(
      '{"title":"Not Found","status":404,"detail":"No fixture for ${options.path}"}',
      404,
      headers: _json,
    );
  }

  static const _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}
