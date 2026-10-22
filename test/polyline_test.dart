import 'package:ams_travel/core/utils/polyline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the example from Google\'s polyline documentation', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points[0].latitude, closeTo(38.5, 1e-5));
    expect(points[0].longitude, closeTo(-120.2, 1e-5));
    expect(points[2].latitude, closeTo(43.252, 1e-5));
    expect(points[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('nothing to decode gives no points', () {
    expect(decodePolyline(null), isEmpty);
    expect(decodePolyline(''), isEmpty);
  });
}
