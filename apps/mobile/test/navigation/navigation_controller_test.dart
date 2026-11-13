import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/models/place.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/navigation/geo.dart';
import 'package:lanka_maps/navigation/navigation_controller.dart';
import 'package:lanka_maps/navigation/position_source.dart';
import 'package:lanka_maps/services/routing_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../support.dart';

void main() {
  late RouteOption route;
  late FakeSpeech speech;
  late List<Uri> routeRequests;
  late NavigationController nav;
  late ManualPositionSource gps;
  var voice = true;

  setUp(() async {
    route = await fixtureRoute();
    speech = FakeSpeech();
    routeRequests = [];
    voice = true;
    gps = ManualPositionSource();
    nav = NavigationController(
      routing: RoutingService(
        baseUrl: 'http://gw',
        client: MockClient((req) async {
          routeRequests.add(req.url);
          return http.Response(valhallaFixture, 200);
        }),
      ),
      speech: speech,
      isVoiceEnabled: () => voice,
      routeAvoid: () => const RouteAvoid(tolls: true),
    );
    await nav.start(
      route: route,
      destination: const Place(name: 'Museum', location: fixtureTo),
      mode: TravelMode.car,
      source: gps,
    );
  });

  tearDown(() => nav.stop());

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('speaks prompts and tracks progress to arrival', () async {
    final cumulative = cumulativeDistances(route.shape);
    for (var d = 0.0; d <= cumulative.last; d += 20) {
      gps.add(pointAlong(route.shape, cumulative, d).point);
      await pump();
    }
    gps.add(route.shape.last);
    await pump();

    expect(nav.hasArrived, isTrue);
    expect(speech.spoken.first, 'Drive east on Galle Road.');
    expect(speech.spoken.last, 'You have arrived at your destination.');
    expect(
      speech.spoken.where((s) => s == 'You have arrived at your destination.'),
      hasLength(1),
    );
    expect(routeRequests, isEmpty);
  });

  test(
    'reroutes once after going off the route, then follows the new route',
    () async {
      gps.add(route.shape.first);
      await pump();
      const away = LatLng(6.917, 79.849);
      for (var i = 0; i < 5; i++) {
        gps.add(away, heading: 180);
        await pump();
      }
      await pump();

      expect(routeRequests, hasLength(1)); // cooldown stops repeat requests
      final body =
          jsonDecode(routeRequests.single.queryParameters['json']!) as Map;
      final from = (body['locations'] as List).first as Map;
      expect(from['lat'], closeTo(6.917, 1e-9));
      expect(from['heading'], 180);
      expect(from['radius'], 10); // fix accuracy 5 m, floored to 10
      // Rerouting must still snap to whatever road the car is on.
      expect(from.containsKey('search_filter'), isFalse);
      expect(body['alternates'], 0);
      expect(body['costing_options'], {
        'auto': {'use_tolls': 0.0},
      });
      expect(speech.spoken, contains('Rerouting.'));
      expect(nav.isRerouting, isFalse);
      expect(nav.isActive, isTrue);
    },
  );

  test('stays quiet when voice guidance is off', () async {
    voice = false;
    gps.add(route.shape.first);
    await pump();
    expect(speech.spoken, isEmpty);
    expect(nav.progress, isNotNull);
  });

  test('stop ends the session and releases the position source', () async {
    gps.add(route.shape.first);
    await pump();
    await nav.stop();
    expect(nav.isActive, isFalse);
    expect(nav.progress, isNull);
    expect(gps.stopped, isTrue);
  });

  test('simulated source drives the whole route', () async {
    await nav.stop();
    final sim = SimulatedPositionSource(
      route.shape,
      metersPerSecond: 20000, // 200 m per 10 ms tick
      tick: const Duration(milliseconds: 10),
    );
    await nav.start(
      route: route,
      destination: const Place(name: 'Museum', location: fixtureTo),
      mode: TravelMode.car,
      source: sim,
      simulated: true,
    );
    for (var i = 0; i < 200 && !nav.hasArrived; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(nav.isSimulated, isTrue);
    expect(nav.hasArrived, isTrue);
  });
}
