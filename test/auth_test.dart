import 'dart:typed_data';

import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/data/auth/keycloak.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// Answers from the fixtures, but turns down [rejected] tokens with 401 and
/// records the Authorization header of every request.
class _Gate implements HttpClientAdapter {
  _Gate(this.rejected);
  final Set<String> rejected;
  final fixtures = FixtureAdapter();
  final headers = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) {
    final auth = o.headers['Authorization'] as String?;
    headers.add(auth);
    if (auth != null && rejected.contains(auth.substring('Bearer '.length))) {
      return Future.value(ResponseBody.fromString('{"title":"Unauthorized","status":401}', 401));
    }
    return fixtures.fetch(o, body, cancel);
  }

  @override
  void close({bool force = false}) {}
}

class _Keycloak extends FakeKeycloak {
  _Keycloak({this.refreshFails = false});
  final bool refreshFails;
  int refreshes = 0;

  @override
  Future<KeycloakTokens> refresh(KeycloakTokens current) async {
    refreshes++;
    if (refreshFails) throw StateError('refresh token expired');
    return KeycloakTokens(accessToken: 'fresh', refreshToken: 'r2', expiresAt: DateTime(2100));
  }
}

Future<(AuthProvider, _Gate, _Keycloak)> _session({
  KeycloakTokens? stored,
  Set<String> rejected = const {},
  bool refreshFails = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final gate = _Gate(rejected);
  final client = ApiClient(adapter: gate);
  final keycloak = _Keycloak(refreshFails: refreshFails);
  final auth = AuthProvider(keycloak: keycloak, store: MemoryTokenStore(stored), api: AmsApi(client), prefs: prefs);
  client.tokens = auth;
  await auth.restore();
  return (auth, gate, keycloak);
}

void main() {
  test('a guest sends no token and still reads', () async {
    final (auth, gate, _) = await _session();
    expect(auth.isSignedIn, isFalse);
    final interests = await AmsApi(ApiClient(tokens: auth, adapter: gate)).interests();
    expect(interests, isNotEmpty);
    expect(gate.headers.single, isNull);
  });

  test('signing in keeps the tokens, sends them, and reads the profile', () async {
    final (auth, gate, _) = await _session();
    expect(await auth.signIn(), isTrue);
    expect(auth.isSignedIn, isTrue);
    expect(auth.user?.fullName, 'Dara Chan');
    expect(auth.preferences?.preferredCurrency, 'USD');
    expect(gate.headers, everyElement('Bearer test-token'));
  });

  test('a turned-down token is refreshed once and the call repeated', () async {
    final (auth, gate, keycloak) = await _session(
      stored: KeycloakTokens(accessToken: 'stale', refreshToken: 'r1', expiresAt: DateTime(2100)),
      rejected: {'stale'},
    );
    await Future<void>.delayed(Duration.zero);
    final me = await AmsApi(ApiClient(tokens: auth, adapter: gate)).me();
    expect(me.email, 'dara.chan+test@gmail.com');
    expect(keycloak.refreshes, 1);
    expect(gate.headers.last, 'Bearer fresh');
    expect(auth.isSignedIn, isTrue);
  });

  test('when the refresh fails the session ends and the read goes on as a guest', () async {
    final (auth, gate, _) = await _session(
      stored: KeycloakTokens(accessToken: 'stale', refreshToken: 'r1', expiresAt: DateTime(2100)),
      rejected: {'stale'},
      refreshFails: true,
    );
    final interests = await AmsApi(ApiClient(tokens: auth, adapter: gate)).interests();
    expect(interests, isNotEmpty);
    expect(gate.headers.last, isNull, reason: 'repeated without a token');
    expect(auth.isSignedIn, isFalse);
    expect(auth.user, isNull);
  });

  test('a token close to expiry is refreshed before it is sent', () async {
    final (auth, gate, keycloak) = await _session(
      stored: KeycloakTokens(accessToken: 'old', refreshToken: 'r1', expiresAt: DateTime.now().add(const Duration(seconds: 5))),
    );
    await AmsApi(ApiClient(tokens: auth, adapter: gate)).interests();
    expect(keycloak.refreshes, greaterThanOrEqualTo(1));
    expect(gate.headers.last, 'Bearer fresh');
  });

  test('signing out forgets the session', () async {
    final (auth, _, _) = await _session(stored: FakeKeycloak.tokens);
    expect(auth.isSignedIn, isTrue);
    await auth.signOut();
    expect(auth.isSignedIn, isFalse);
    expect(auth.user, isNull);
  });
}
