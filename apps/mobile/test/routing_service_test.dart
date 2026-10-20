import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/services/routing_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  // Real Valhalla 3.9.1 response (Colombo test grid, auto, alternates=2).
  final fixture = File('test/fixtures/valhalla_route.json').readAsStringSync();
  const from = LatLng(6.919, 79.849);
  const to = LatLng(6.937, 79.865);

  test('sends a GET request with the Valhalla JSON query', () async {
    late Uri captured;
    final service = RoutingService(
      baseUrl: 'http://gw',
      client: MockClient((req) async {
        captured = req.url;
        return http.Response(fixture, 200);
      }),
    );

    await service.route(from, to, mode: TravelMode.bicycle);

    expect(captured.path, '/valhalla/route');
    final body = jsonDecode(captured.queryParameters['json']!) as Map;
    expect(body['costing'], 'bicycle');
    expect(body['alternates'], 2);
    final locations = body['locations'] as List;
    expect(locations, hasLength(2));
    expect(locations[0]['lat'], closeTo(6.919, 1e-9));
    expect(locations[0]['lon'], closeTo(79.849, 1e-9));
    expect(locations[1]['lat'], closeTo(6.937, 1e-9));
    expect(locations[1]['lon'], closeTo(79.865, 1e-9));
  });

  test('parses the main route and alternates', () async {
    final service = RoutingService(
      baseUrl: 'http://gw',
      client: MockClient((_) async => http.Response(fixture, 200)),
    );

    final routes = await service.route(from, to);

    expect(routes, hasLength(3));
    final best = routes.first;
    expect(best.lengthKm, 3.77);
    expect(best.timeSeconds, closeTo(243.3, 0.1));
    expect(best.maneuvers.map((m) => m.instruction), [
      'Drive east on Galle Road.',
      'Turn left onto Ananda Coomaraswamy Mawatha.',
      'Turn right onto Havelock Road.',
      'Turn left onto Ward Place.',
      'You have arrived at your destination.',
    ]);
    expect(best.maneuvers[1].type, 15); // left turn
    expect(best.shape.first.latitude, closeTo(from.latitude, 1e-4));
    expect(best.shape.first.longitude, closeTo(from.longitude, 1e-4));
    expect(best.shape.last.latitude, closeTo(to.latitude, 1e-4));
    expect(best.shape.last.longitude, closeTo(to.longitude, 1e-4));
    expect(best.bounds.southwest.latitude, lessThanOrEqualTo(6.919));
    expect(best.bounds.northeast.longitude, greaterThanOrEqualTo(79.865));

    expect(routes[1].lengthKm, 3.77);
    expect(routes[2].lengthKm, 4.215);
  });

  test('surfaces Valhalla error messages', () async {
    final service = RoutingService(
      baseUrl: 'http://gw',
      client: MockClient(
        (_) async => http.Response(
          '{"error_code":171,"error":"No suitable edges near location",'
          '"status_code":400,"status":"Bad Request"}',
          400,
        ),
      ),
    );

    expect(
      () => service.route(from, to),
      throwsA(
        isA<RoutingException>().having(
          (e) => e.message,
          'message',
          'No suitable edges near location',
        ),
      ),
    );
  });

  test('reports non-JSON gateway errors', () async {
    final service = RoutingService(
      baseUrl: 'http://gw',
      client: MockClient((_) async => http.Response('Bad Gateway', 502)),
    );

    expect(
      () => service.route(from, to),
      throwsA(
        isA<RoutingException>().having(
          (e) => e.message,
          'message',
          contains('HTTP 502'),
        ),
      ),
    );
  });
}
