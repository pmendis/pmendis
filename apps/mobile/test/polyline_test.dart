import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/services/polyline.dart';

void main() {
  test('decodes precision-5 polyline (Google reference example)', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-9));
    expect(points[0].longitude, closeTo(-120.2, 1e-9));
    expect(points[1].latitude, closeTo(40.7, 1e-9));
    expect(points[1].longitude, closeTo(-120.95, 1e-9));
    expect(points[2].latitude, closeTo(43.252, 1e-9));
    expect(points[2].longitude, closeTo(-126.453, 1e-9));
  });

  test('empty string decodes to no points', () {
    expect(decodePolyline(''), isEmpty);
  });
}
