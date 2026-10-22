/// Small helpers so `fromJson` factories tolerate slightly different backend
/// shapes (ints vs doubles, numbers sent as strings, missing lists).
typedef Json = Map<String, dynamic>;

String str(Json json, String key, {String fallback = ''}) => json[key]?.toString() ?? fallback;

/// Null when missing or blank, so callers' `??` fallbacks also cover "".
String? strOrNull(Json json, String key) {
  final s = json[key]?.toString();
  return s == null || s.trim().isEmpty ? null : s;
}

double? dbl(Json json, String key) {
  final v = json[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int integer(Json json, String key, {int fallback = 0}) {
  final v = json[key];
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? intOrNull(Json json, String key) => json[key] == null ? null : integer(json, key);

bool boolean(Json json, String key) {
  final v = json[key];
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return false;
}

bool? boolOrNull(Json json, String key) => json[key] == null ? null : boolean(json, key);

DateTime? dateOrNull(Json json, String key) => DateTime.tryParse(strOrNull(json, key) ?? '');

List<String> strList(Json json, String key) {
  final v = json[key];
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

/// The nested object at [key], or an empty one when missing.
Json obj(Json json, String key) {
  final v = json[key];
  return v is Map ? Json.from(v) : {};
}

List<T> objList<T>(Json json, String key, T Function(Json) fromJson) {
  final v = json[key];
  if (v is List) return v.whereType<Map>().map((e) => fromJson(Json.from(e))).toList();
  return const [];
}
