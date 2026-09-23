/// Small helpers so `fromJson` factories tolerate slightly different backend
/// shapes (ints vs doubles, missing lists, snake_case vs camelCase).
typedef Json = Map<String, dynamic>;

T? pick<T>(Json json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) return v as T;
  }
  return null;
}

String str(Json json, String key, {List<String> alt = const [], String fallback = ''}) {
  final v = pick<Object>(json, [key, ...alt]);
  return v?.toString() ?? fallback;
}

String? strOrNull(Json json, String key, {List<String> alt = const []}) =>
    pick<Object>(json, [key, ...alt])?.toString();

double? dbl(Json json, String key, {List<String> alt = const []}) {
  final v = pick<Object>(json, [key, ...alt]);
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int integer(Json json, String key, {List<String> alt = const [], int fallback = 0}) {
  final v = pick<Object>(json, [key, ...alt]);
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool boolean(Json json, String key, {List<String> alt = const []}) {
  final v = pick<Object>(json, [key, ...alt]);
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return false;
}

List<String> strList(Json json, String key, {List<String> alt = const []}) {
  final v = pick<Object>(json, [key, ...alt]);
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

List<T> objList<T>(Json json, String key, T Function(Json) fromJson, {List<String> alt = const []}) {
  final v = pick<Object>(json, [key, ...alt]);
  if (v is List) return v.whereType<Map>().map((e) => fromJson(Json.from(e))).toList();
  return const [];
}
