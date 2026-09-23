import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Turns a list of stops into a line that follows real roads.
///
/// Uses the public OSRM demo server, which needs no key. Its terms do not
/// allow production traffic, so before release either point [_base] at your
/// own OSRM/Mapbox/Google Directions endpoint, or have the API send each
/// corridor's road geometry and skip this service entirely.
class RoutingService {
  RoutingService._();

  static const _base = 'https://router.project-osrm.org/route/v1/driving/';

  static final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 12)));

  /// Roads are the same on every launch, so a resolved route is kept for the
  /// life of the session.
  static final Map<String, List<LatLng>> _cache = {};

  /// Road geometry through [stops], or the straight line between them when the
  /// service cannot be reached. Never throws.
  static Future<List<LatLng>> road(List<LatLng> stops) async {
    if (stops.length < 2) return stops;
    final key = stops.map((p) => '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}').join(';');
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      // OSRM takes lon,lat pairs and returns GeoJSON [lon, lat] coordinates.
      final path = stops.map((p) => '${p.longitude},${p.latitude}').join(';');
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base$path',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = res.data?['routes'] as List?;
      final coords = (routes?.firstOrNull as Map?)?['geometry']?['coordinates'] as List?;
      if (coords == null || coords.length < 2) return stops;
      final line = [
        for (final c in coords.whereType<List>()) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      return _cache[key] = line;
    } on Object {
      // Offline or the service is down — the straight line still shows the shape.
      return stops;
    }
  }
}
