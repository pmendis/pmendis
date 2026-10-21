import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/navigation/geo.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  const colombo = LatLng(6.9271, 79.8612);
  const kandy = LatLng(7.2906, 80.6337);

  test('distanceMeters matches the known Colombo–Kandy straight line', () {
    expect(distanceMeters(colombo, kandy), closeTo(94400, 500));
    expect(distanceMeters(colombo, colombo), 0);
  });

  test('bearingDegrees', () {
    expect(
      bearingDegrees(const LatLng(7, 80), const LatLng(7.1, 80)),
      closeTo(0, 0.01),
    );
    expect(
      bearingDegrees(const LatLng(7, 80), const LatLng(7, 80.1)),
      closeTo(90, 0.1),
    );
    expect(
      bearingDegrees(const LatLng(7, 80), const LatLng(6.9, 80)),
      closeTo(180, 0.01),
    );
    expect(
      bearingDegrees(const LatLng(7, 80), const LatLng(7, 79.9)),
      closeTo(270, 0.1),
    );
  });

  test('projectOnSegment clamps to the segment and measures the offset', () {
    const a = LatLng(7, 80), b = LatLng(7, 80.01);
    final mid = projectOnSegment(const LatLng(7.001, 80.005), a, b);
    expect(mid.t, closeTo(0.5, 1e-6));
    expect(mid.point.latitude, closeTo(7, 1e-9));
    expect(mid.distance, closeTo(111.2, 0.5));

    final before = projectOnSegment(const LatLng(7, 79.99), a, b);
    expect(before.t, 0);
    expect(before.point, a);
  });

  test('pointAlong walks the line', () {
    const line = [LatLng(7, 80), LatLng(7, 80.01), LatLng(7.01, 80.01)];
    final cumulative = cumulativeDistances(line);
    expect(cumulative.first, 0);
    expect(cumulative[1], closeTo(1103.6, 1));

    final half = pointAlong(line, cumulative, cumulative[1] / 2);
    expect(half.point.longitude, closeTo(80.005, 1e-6));
    expect(half.bearing, closeTo(90, 0.1));

    final corner = pointAlong(line, cumulative, cumulative[1] + 10);
    expect(corner.bearing, closeTo(0, 0.1));

    expect(pointAlong(line, cumulative, 1e9).point, line.last);
    expect(pointAlong(line, cumulative, -5).point, line.first);
  });
}
