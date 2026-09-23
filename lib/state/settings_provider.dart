import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/geo.dart';

/// Distances in kilometres or in miles.
enum DistanceUnit { metric, imperial }

/// What prices are shown in.
enum Currency { usd, khr }

/// What the traveller chose on the Preference page, kept on the device.
///
/// TODO(api): move to the account once the backend stores settings.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs)
    : _unit = (_prefs.getString(_unitKey) == 'imperial') ? DistanceUnit.imperial : DistanceUnit.metric,
      _currency = (_prefs.getString(_currencyKey) == 'khr') ? Currency.khr : Currency.usd,
      _notifications = _prefs.getBool(_notifyKey) ?? true {
    // Distance labels read the choice straight from here.
    useMiles = _unit == DistanceUnit.imperial;
  }

  static const _unitKey = 'ams-travel:unit';
  static const _currencyKey = 'ams-travel:currency';

  /// Riel per dollar. TODO(api): take the day's rate from the backend.
  static const rielPerDollar = 4100;
  static const _notifyKey = 'ams-travel:notifications';

  final SharedPreferences _prefs;
  DistanceUnit _unit;
  Currency _currency;
  bool _notifications;

  DistanceUnit get unit => _unit;
  Currency get currency => _currency;
  bool get notifications => _notifications;

  String get currencySymbol => _currency == Currency.usd ? '\$' : '៛';

  /// A dollar amount from the data, written in the chosen currency.
  String price(double usd) {
    if (_currency == Currency.usd) return '\$${usd.toStringAsFixed(2)}';
    final riel = (usd * rielPerDollar).round();
    return '៛${thousands(riel)}';
  }

  void setCurrency(Currency value) {
    if (value == _currency) return;
    _currency = value;
    _prefs.setString(_currencyKey, value.name);
    notifyListeners();
  }

  void setUnit(DistanceUnit value) {
    if (value == _unit) return;
    _unit = value;
    useMiles = value == DistanceUnit.imperial;
    _prefs.setString(_unitKey, value.name);
    notifyListeners();
  }

  void setNotifications(bool value) {
    if (value == _notifications) return;
    _notifications = value;
    _prefs.setBool(_notifyKey, value);
    notifyListeners();
  }
}
