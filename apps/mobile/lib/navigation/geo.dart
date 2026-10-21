import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

const _earthRadius = 6371008.8;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in meters.
double distanceMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b], 0–360 degrees clockwise from north.
double bearingDegrees(LatLng a, LatLng b) {
  final lat1 = _rad(a.latitude), lat2 = _rad(b.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

LatLng interpolate(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);

class SegmentProjection {
  const SegmentProjection(this.point, this.t, this.distance);

  /// Closest point on the segment.
  final LatLng point;

  /// Position of [point] along the segment, 0 (start) to 1 (end).
  final double t;

  /// Meters from the projected point to the original point.
  final double distance;
}

/// Projects [p] onto segment [a]–[b] using a local flat-earth approximation,
/// which is accurate to well under a meter at street scale.
SegmentProjection projectOnSegment(LatLng p, LatLng a, LatLng b) {
  final cosLat = math.cos(_rad(p.latitude));
  final ax = (a.longitude - p.longitude) * cosLat, ay = a.latitude - p.latitude;
  final bx = (b.longitude - p.longitude) * cosLat, by = b.latitude - p.latitude;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final point = interpolate(a, b, t);
  return SegmentProjection(point, t, distanceMeters(p, point));
}

/// Cumulative distance in meters at each vertex of [line].
List<double> cumulativeDistances(List<LatLng> line) {
  final result = List<double>.filled(line.length, 0);
  for (var i = 1; i < line.length; i++) {
    result[i] = result[i - 1] + distanceMeters(line[i - 1], line[i]);
  }
  return result;
}

/// The point [meters] along [line] and the bearing of the line there.
({LatLng point, double bearing}) pointAlong(
  List<LatLng> line,
  List<double> cumulative,
  double meters,
) {
  if (line.length == 1 || meters <= 0) {
    return (
      point: line.first,
      bearing: line.length > 1 ? bearingDegrees(line[0], line[1]) : 0,
    );
  }
  for (var i = 1; i < line.length; i++) {
    if (cumulative[i] >= meters) {
      final segment = cumulative[i] - cumulative[i - 1];
      final t = segment == 0 ? 0.0 : (meters - cumulative[i - 1]) / segment;
      return (
        point: interpolate(line[i - 1], line[i], t),
        bearing: bearingDegrees(line[i - 1], line[i]),
      );
    }
  }
  final n = line.length;
  return (point: line.last, bearing: bearingDegrees(line[n - 2], line[n - 1]));
}
