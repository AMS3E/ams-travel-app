import 'package:latlong2/latlong.dart';

/// Decodes a Google encoded polyline (precision 5), the shape the API sends
/// for corridor routes (`encodedPolyline`, a stop's `routePolyline`).
List<LatLng> decodePolyline(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;

  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < encoded.length);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  try {
    while (index < encoded.length) {
      lat += next();
      if (index >= encoded.length) break;
      lng += next();
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
  } on RangeError {
    // A cut-off string: keep the points read so far.
  }
  return points;
}
