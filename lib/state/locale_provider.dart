import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs) : _isKhmer = _prefs.getBool(_key) ?? false;

  static const _key = 'ams-travel:lang-km';
  final SharedPreferences _prefs;
  bool _isKhmer;

  bool get isKhmer => _isKhmer;

  void setKhmer(bool value) {
    if (value == _isKhmer) return;
    _isKhmer = value;
    _prefs.setBool(_key, value);
    notifyListeners();
  }

  /// Picks the Khmer variant of a content field when Khmer is on and one exists.
  String pick(String en, String? kh) => _isKhmer && kh != null && kh.isNotEmpty ? kh : en;
}
