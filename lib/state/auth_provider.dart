import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';

/// Holds the signed-in session and persists it across launches.
///
/// NOTE: for production, move the token to `flutter_secure_storage`.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo, this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _session = AuthSession.fromJson(Json.from(jsonDecode(raw) as Map));
      } catch (_) {
        _prefs.remove(_key);
      }
    }
  }

  static const _key = 'ams-travel:session';
  final AuthRepository _repo;
  final SharedPreferences _prefs;
  AuthSession? _session;

  AuthSession? get session => _session;
  AppUser? get user => _session?.user;
  String? get token => _session?.token;
  bool get isSignedIn => _session != null;

  Future<void> login(String identifier, String password) async {
    _setSession(await _repo.login(identifier: identifier.trim(), password: password));
  }

  Future<void> register(String username, String email, String password) async {
    _setSession(await _repo.register(username: username.trim(), email: email.trim(), password: password));
  }

  Future<void> forgotPassword(String email) => _repo.forgotPassword(email.trim());

  Future<void> logout() async {
    await _repo.logout();
    _session = null;
    await _prefs.remove(_key);
    notifyListeners();
  }

  /// Saves edits from the account form. Local for now.
  ///
  /// TODO(api): send these to `PATCH /me` and keep what comes back.
  Future<void> updateUser(AppUser user) async {
    final current = _session;
    if (current == null) return;
    _setSession(AuthSession(token: current.token, user: user));
  }

  void _setSession(AuthSession s) {
    _session = s;
    _prefs.setString(_key, jsonEncode(s.toJson()));
    notifyListeners();
  }
}
