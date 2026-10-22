import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language of the app's own text: English or Khmer. A guest keeps it on
/// the phone; signed in, the shell applies the account's
/// `preferredLanguage` here and the Language page saves a change to it.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs) : _isKhmer = _prefs.getBool(_key) ?? false;

  static const _key = 'ams-travel:lang-km';
  final SharedPreferences _prefs;
  bool _isKhmer;

  bool get isKhmer => _isKhmer;

  /// As `preferredLanguage` spells it: "en" or "km".
  String get code => _isKhmer ? 'km' : 'en';

  void setKhmer(bool value) {
    if (value == _isKhmer) return;
    _isKhmer = value;
    _prefs.setBool(_key, value);
    notifyListeners();
  }

  /// Applies a `preferredLanguage` from the account; ignores anything else.
  void applyCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'km':
        setKhmer(true);
      case 'en':
        setKhmer(false);
    }
  }
}
