import 'dart:math' as math;

/// "Kratié" → "kratie", "Preah Sihanouk" → "preah-sihanouk".
/// Matches the website's province URLs.
String slugify(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèê]'), 'e')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

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
