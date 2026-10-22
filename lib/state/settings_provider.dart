import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/geo.dart';
import '../data/api/account.dart';

/// Distances in kilometres or in miles.
enum DistanceUnit {
  metric('KM'),
  imperial('MI');

  const DistanceUnit(this.code);

  /// As `distanceUnit` spells it.
  final String code;

  static DistanceUnit? parse(String? code) => values.where((u) => u.code == code?.toUpperCase()).firstOrNull;
}

/// The currency the traveller prefers. Prices show in the currency the API
/// sends with each one: converting them is parked 2026-10-14 (R-006).
enum Currency {
  usd('USD'),
  khr('KHR');

  const Currency(this.code);

  /// As `preferredCurrency` spells it.
  final String code;

  static Currency? parse(String? code) => values.where((c) => c.code == code?.toUpperCase()).firstOrNull;
}

/// What the traveller chose on the Preference page.
///
/// A guest keeps everything on the phone. Signed in, currency, distance unit
/// and notifications live in `GET/PUT /preferences/me`: the shell copies the
/// account's choice here with [apply], and the preference pages save a change
/// to the account as well as here.
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
  static const _notifyKey = 'ams-travel:notifications';

  final SharedPreferences _prefs;
  DistanceUnit _unit;
  Currency _currency;
  bool _notifications;

  DistanceUnit get unit => _unit;
  Currency get currency => _currency;
  bool get notifications => _notifications;

  /// Takes the account's currency, distance unit and notification choice.
  void apply(UserPreferences prefs) {
    final currency = Currency.parse(prefs.preferredCurrency);
    if (currency != null) _setCurrency(currency, notify: false);
    final unit = DistanceUnit.parse(prefs.distanceUnit);
    if (unit != null) _setUnit(unit, notify: false);
    _setNotifications(prefs.notificationPush, notify: false);
    notifyListeners();
  }

  void setCurrency(Currency value) => _setCurrency(value);

  void _setCurrency(Currency value, {bool notify = true}) {
    if (value == _currency) return;
    _currency = value;
    _prefs.setString(_currencyKey, value.name);
    if (notify) notifyListeners();
  }

  void setUnit(DistanceUnit value) => _setUnit(value);

  void _setUnit(DistanceUnit value, {bool notify = true}) {
    if (value == _unit) return;
    _unit = value;
    useMiles = value == DistanceUnit.imperial;
    _prefs.setString(_unitKey, value.name);
    if (notify) notifyListeners();
  }

  void setNotifications(bool value) => _setNotifications(value);

  void _setNotifications(bool value, {bool notify = true}) {
    if (value == _notifications) return;
    _notifications = value;
    _prefs.setBool(_notifyKey, value);
    if (notify) notifyListeners();
  }
}
