import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../data/api/ams_api.dart';
import '../data/auth/keycloak.dart';

/// The traveller's session: Keycloak tokens, then their profile and
/// preferences from the API. A guest has none of these and every read still
/// works.
///
/// It is also where [ApiClient] gets the bearer token: refreshed shortly
/// before it expires, and once more when the API turns it down.
class AuthProvider extends ChangeNotifier implements TokenSource {
  AuthProvider({required this._keycloak, required this._store, required this._api, required this._prefs}) {
    final raw = _prefs.getString(_profileKey);
    if (raw != null) {
      try {
        _user = UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        _prefs.remove(_profileKey);
      }
    }
  }

  static const _profileKey = 'ams-travel:profile';

  final KeycloakClient _keycloak;
  final TokenStore _store;
  final AmsApi _api;
  final SharedPreferences _prefs;

  KeycloakTokens? _tokens;
  UserProfile? _user;
  UserPreferences? _preferences;
  Future<KeycloakTokens?>? _refreshing;
  bool _busy = false;

  bool get isSignedIn => _tokens != null;

  /// The profile from `GET /users/me`; kept from the last launch until it
  /// is read again.
  UserProfile? get user => isSignedIn ? _user : null;

  /// Null when signed out, '' while the profile is still loading: a key for
  /// per-account data that changes when the account does.
  String? get userId => isSignedIn ? (_user?.id ?? '') : null;

  UserPreferences? get preferences => isSignedIn ? _preferences : null;

  /// True while Keycloak's page is open or the session is being set up.
  bool get busy => _busy;

  /// Picks the session up from the last launch. Call once at start-up.
  Future<void> restore([Future<KeycloakTokens?>? stored]) async {
    _tokens = await (stored ?? _store.read());
    if (_tokens == null) {
      _user = null;
      if (_prefs.containsKey(_profileKey)) await _prefs.remove(_profileKey);
    }
    notifyListeners();
    if (_tokens != null) unawaited(_loadAccount());
  }

  /// Opens Keycloak's sign-in page. True when the traveller came back signed in.
  Future<bool> signIn() => _start(_keycloak.signIn);

  /// Opens Keycloak's registration page, which ends with the email code.
  Future<bool> register() => _start(_keycloak.register);

  Future<bool> _start(Future<KeycloakTokens?> Function() open) async {
    if (_busy) {
      authLog('sign-in ignored: a flow is already open');
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      final tokens = await open();
      if (tokens == null) {
        authLog('sign-in ended without tokens (cancelled)');
        return false;
      }
      await _setTokens(tokens);
      // The first request with a new token creates the traveller on the API.
      await _loadAccount();
      return true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Ends the session on Keycloak, then forgets it here. Forgetting it here
  /// happens even if the browser step fails or is closed.
  Future<void> signOut() async {
    final tokens = _tokens;
    if (tokens != null) {
      try {
        await _keycloak.signOut(tokens);
      } catch (e, st) {
        // The local session ends regardless.
        authError('sign-out browser step failed', e, st);
      }
    }
    await _forget();
  }

  /// Reads `GET /users/me` and `GET /preferences/me` again.
  Future<void> refreshAccount() => _loadAccount();

  Future<void> _loadAccount() async {
    if (_tokens == null) return;
    try {
      final (me, prefs) = await (_api.me(), _api.preferences()).wait;
      _setUser(me);
      _preferences = prefs;
      notifyListeners();
    } on ParallelWaitError<(UserProfile?, UserPreferences?), (AsyncError?, AsyncError?)> catch (e) {
      final (me, prefs) = e.values;
      final (meError, prefsError) = e.errors;
      if (meError != null) authError('GET /users/me failed', meError.error, meError.stackTrace);
      if (prefsError != null) authError('GET /preferences/me failed', prefsError.error, prefsError.stackTrace);
      if (me != null) _setUser(me);
      if (prefs != null) _preferences = prefs;
      notifyListeners();
    }
  }

  /// `PUT /users/me`, keeping what the API answers. The API clears any
  /// field left out, so the fields not given here are sent as they are now.
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarKey,
    String? homeProvinceId,
    bool clearHomeProvince = false,
  }) async {
    final current = _user;
    final me = await _api.updateMe(
      fullName: fullName ?? current?.fullName,
      phone: phone ?? current?.phone,
      avatarKey: avatarKey ?? current?.avatarKey,
      homeProvinceId: clearHomeProvince ? null : (homeProvinceId ?? current?.homeProvinceId),
    );
    _setUser(me);
    notifyListeners();
    return me;
  }

  /// `PUT /preferences/me`, keeping what the API answers.
  Future<UserPreferences> savePreferences(UserPreferences prefs) async {
    final saved = await _api.savePreferences(prefs);
    _preferences = saved;
    notifyListeners();
    return saved;
  }

  void _setUser(UserProfile me) {
    _user = me;
    _prefs.setString(_profileKey, jsonEncode(me.toJson()));
  }

  Future<void> _setTokens(KeycloakTokens tokens) async {
    _tokens = tokens;
    await _store.write(tokens);
  }

  Future<void> _forget() async {
    _tokens = null;
    _user = null;
    _preferences = null;
    await _store.clear();
    await _prefs.remove(_profileKey);
    notifyListeners();
  }

  // TokenSource

  @override
  Future<String?> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) return null;
    if (!tokens.expiresWithin(const Duration(seconds: 30))) return tokens.accessToken;
    return (await _refresh())?.accessToken;
  }

  @override
  Future<String?> onRejected(String token) async {
    final tokens = _tokens;
    if (tokens == null) return null;
    // Another request may have refreshed already.
    if (tokens.accessToken != token) return tokens.accessToken;
    return (await _refresh())?.accessToken;
  }

  /// One refresh at a time; the session ends if Keycloak refuses.
  Future<KeycloakTokens?> _refresh() => _refreshing ??= () async {
    try {
      final current = _tokens;
      if (current?.refreshToken == null) {
        await _forget();
        return null;
      }
      final fresh = await _keycloak.refresh(current!);
      await _setTokens(fresh);
      return fresh;
    } catch (e, st) {
      authError('refresh refused, signing out', e, st);
      await _forget();
      return null;
    } finally {
      _refreshing = null;
    }
  }();
}
