import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/navigation/geo.dart';
import 'package:lanka_maps/navigation/route_tracker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../support.dart';

void main() {
  test('follows the route maneuver by maneuver until arrival', () async {
    final route = await fixtureRoute();
    final tracker = RouteTracker(route);
    final cumulative = cumulativeDistances(route.shape);
    final total = cumulative.last;
    expect(total, closeTo(route.lengthKm * 1000, 30));

    final seenManeuvers = <int>[];
    var lastRemaining = double.infinity;
    var lastSeconds = double.infinity;
    for (var d = 0.0; d <= total; d += 10) {
      final p = tracker.update(pointAlong(route.shape, cumulative, d).point);
      expect(p.offRoute, isFalse);
      expect(p.distanceFromRoute, lessThan(1));
      expect(p.traveledMeters, closeTo(d, 1));
      expect(p.remainingMeters, lessThanOrEqualTo(lastRemaining));
      expect(p.remainingSeconds, lessThanOrEqualTo(lastSeconds + 1e-9));
      lastRemaining = p.remainingMeters;
      lastSeconds = p.remainingSeconds;
      if (seenManeuvers.isEmpty ||
          seenManeuvers.last != p.currentManeuverIndex) {
        seenManeuvers.add(p.currentManeuverIndex);
      }
    }
    expect(seenManeuvers, [0, 1, 2, 3]);

    final end = tracker.update(route.shape.last);
    expect(end.arrived, isTrue);
    expect(end.remainingMeters, closeTo(0, 1));
    expect(end.remainingSeconds, closeTo(0, 1));
  });

  test(
    'reports distance to the next turn and full time at the start',
    () async {
      final route = await fixtureRoute();
      final p = RouteTracker(route).update(route.shape.first);
      expect(p.currentManeuverIndex, 0);
      expect(p.nextManeuverIndex, 1);
      expect(p.distanceToNextManeuver, closeTo(884, 15));
      expect(p.remainingSeconds, closeTo(route.timeSeconds, 1));
      expect(p.arrived, isFalse);
    },
  );

  test(
    'needs several fixes away from the route before going off-route',
    () async {
      final route = await fixtureRoute();
      final tracker = RouteTracker(route);
      tracker.update(route.shape.first);

      // ~220 m south of the start, in the sea.
      const away = LatLng(6.917, 79.849);
      expect(tracker.update(away).offRoute, isFalse);
      expect(tracker.update(away).offRoute, isFalse);
      expect(tracker.update(away).offRoute, isTrue);

      // Back on the route clears it immediately.
      expect(tracker.update(route.shape.first).offRoute, isFalse);
    },
  );

  test('a poor GPS accuracy widens the on-route corridor', () async {
    final route = await fixtureRoute();
    final tracker = RouteTracker(route);
    const away = LatLng(6.9183, 79.851); // ~80 m off the first street
    for (var i = 0; i < 5; i++) {
      expect(tracker.update(away, accuracy: 100).offRoute, isFalse);
    }
  });

  test('does not arrive early when merely passing near the end', () async {
    final route = await fixtureRoute();
    final tracker = RouteTracker(route);
    // The destination is ~70 m from no other part of this route, but being
    // far from the route entirely must never count as arrival.
    final p = tracker.update(const LatLng(6.95, 79.88));
    expect(p.arrived, isFalse);
  });

  test('a route whose start and end are the same point arrives at once', () {
    const here = LatLng(6.93, 79.85);
    final tracker = RouteTracker(
      const RouteOption(
        shape: [here, here],
        lengthKm: 0,
        timeSeconds: 0,
        maneuvers: [
          Maneuver(
            instruction: 'Head north.',
            lengthKm: 0,
            timeSeconds: 0,
            type: 1,
          ),
          Maneuver(
            instruction: 'You have arrived.',
            lengthKm: 0,
            timeSeconds: 0,
            type: 4,
          ),
        ],
      ),
    );
    final p = tracker.update(here);
    expect(p.arrived, isTrue);
    expect(p.remainingMeters, 0);
  });
}
