import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/route.dart';
import 'geo.dart';

/// Where the user is along the active route.
class RouteProgress {
  const RouteProgress({
    required this.position,
    required this.snapped,
    required this.bearing,
    required this.distanceFromRoute,
    required this.traveledMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.currentManeuverIndex,
    required this.distanceToNextManeuver,
    required this.offRoute,
    required this.arrived,
  });

  /// Raw GPS position.
  final LatLng position;

  /// [position] snapped onto the route line.
  final LatLng snapped;

  /// Direction of the route at [snapped], degrees from north.
  final double bearing;
  final double distanceFromRoute;
  final double traveledMeters;
  final double remainingMeters;
  final double remainingSeconds;

  /// The maneuver being followed now; the next one is index + 1.
  final int currentManeuverIndex;
  final double distanceToNextManeuver;
  final bool offRoute;
  final bool arrived;

  int get nextManeuverIndex => currentManeuverIndex + 1;
}

/// Matches GPS fixes to a route: snapping, maneuver progress, remaining
/// distance and time, off-route and arrival detection.
class RouteTracker {
  RouteTracker(
    this.route, {
    this.offRouteMeters = 50,
    this.offRouteFixes = 3,
    this.arrivalMeters = 25,
  }) : _cumulative = cumulativeDistances(route.shape) {
    _maneuverStart = [
      for (final m in route.maneuvers)
        _cumulative[m.beginShapeIndex.clamp(0, _cumulative.length - 1)],
    ];
  }

  final RouteOption route;

  /// Distance from the route beyond which a fix counts as off-route
  /// (or the fix's accuracy, if larger).
  final double offRouteMeters;

  /// Consecutive off-route fixes needed before reporting off-route, so one
  /// noisy reading doesn't trigger a reroute.
  final int offRouteFixes;
  final double arrivalMeters;

  final List<double> _cumulative;
  late final List<double> _maneuverStart;
  int _segment = 0;
  int _offRouteCount = 0;
  bool _arrived = false;

  double get totalMeters => _cumulative.last;

  RouteProgress update(LatLng position, {double accuracy = 0}) {
    final shape = route.shape;
    var best = _closestSegment(position, from: _segment - 2, aheadMeters: 1000);
    final threshold = accuracy > offRouteMeters ? accuracy : offRouteMeters;
    if (best.projection.distance > threshold) {
      // Maybe we skipped ahead (GPS gap) or the window is wrong: search all.
      final global = _closestSegment(
        position,
        from: 0,
        aheadMeters: double.infinity,
      );
      if (global.projection.distance <= threshold) best = global;
    }

    final onRoute = best.projection.distance <= threshold;
    if (onRoute) {
      _segment = best.index;
      _offRouteCount = 0;
    } else {
      _offRouteCount++;
    }

    final traveled =
        _cumulative[best.index] +
        best.projection.t *
            (_cumulative[best.index + 1] - _cumulative[best.index]);
    final remaining = (totalMeters - traveled).clamp(0.0, double.infinity);
    if (remaining <= arrivalMeters && onRoute) _arrived = true;

    var current = 0;
    for (var i = 0; i < _maneuverStart.length; i++) {
      if (_maneuverStart[i] <= traveled + 0.5) current = i;
    }
    final next = (current + 1).clamp(0, route.maneuvers.length - 1);
    final distanceToNext = (_maneuverStart[next] - traveled).clamp(
      0.0,
      double.infinity,
    );

    return RouteProgress(
      position: position,
      snapped: best.projection.point,
      bearing: bearingDegrees(shape[best.index], shape[best.index + 1]),
      distanceFromRoute: best.projection.distance,
      traveledMeters: traveled,
      remainingMeters: remaining,
      remainingSeconds: _remainingSeconds(current, traveled),
      currentManeuverIndex: current,
      distanceToNextManeuver: distanceToNext,
      offRoute: _offRouteCount >= offRouteFixes,
      arrived: _arrived,
    );
  }

  /// Valhalla's per-maneuver times, with the current one pro-rated.
  double _remainingSeconds(int current, double traveled) {
    final maneuvers = route.maneuvers;
    var seconds = 0.0;
    for (var i = current + 1; i < maneuvers.length; i++) {
      seconds += maneuvers[i].timeSeconds;
    }
    final start = _maneuverStart[current];
    final end = current + 1 < maneuvers.length
        ? _maneuverStart[current + 1]
        : totalMeters;
    final length = end - start;
    final fractionLeft = length <= 0
        ? 0.0
        : ((end - traveled) / length).clamp(0.0, 1.0);
    return seconds + maneuvers[current].timeSeconds * fractionLeft;
  }

  ({int index, SegmentProjection projection}) _closestSegment(
    LatLng p, {
    required int from,
    required double aheadMeters,
  }) {
    final shape = route.shape;
    final start = from.clamp(0, shape.length - 2);
    final limit = _cumulative[_segment] + aheadMeters;
    var bestIndex = start;
    var best = projectOnSegment(p, shape[start], shape[start + 1]);
    for (var i = start + 1; i < shape.length - 1; i++) {
      if (_cumulative[i] > limit) break;
      final candidate = projectOnSegment(p, shape[i], shape[i + 1]);
      if (candidate.distance < best.distance) {
        best = candidate;
        bestIndex = i;
      }
    }
    return (index: bestIndex, projection: best);
  }
}
