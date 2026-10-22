/// "Kratié" → "kratie", "Preah Sihanouk" → "preah-sihanouk".
/// Matches the website's province URLs.
String slugify(String s) =>
    s.toLowerCase().replaceAll(_accentedE, 'e').replaceAll(_nonSlug, '-').replaceAll(_edgeDashes, '');

final _accentedE = RegExp('[éèê]');
final _nonSlug = RegExp(r'[^a-z0-9]+');
final _edgeDashes = RegExp(r'^-+|-+$');

/// Distances follow the Preference page: kilometres, or miles when this is on.
bool useMiles = false;

/// The unit that goes after a [formatKm] number.
String get distanceUnit => useMiles ? 'mi' : 'km';

String formatKm(double km) {
  final value = useMiles ? km * 0.621371 : km;
  return value < 10 ? value.toStringAsFixed(1).replaceAll('.0', '') : value.round().toString();
}

/// 1453 → "1,453". Review counts read better grouped.
String thousands(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
