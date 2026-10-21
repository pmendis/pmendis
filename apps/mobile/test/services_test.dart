import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/services/external_navigation.dart';
import 'package:lanka_maps/services/osm_notes_service.dart';
import 'package:lanka_maps/services/routing_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support.dart';

void main() {
  group('OsmNotesService', () {
    test('posts an anonymous note and returns its web page', () async {
      late http.Request sent;
      final notes = OsmNotesService(
        apiBaseUrl: 'https://api.openstreetmap.org',
        client: MockClient((req) async {
          sent = req;
          return http.Response(
            '{"type":"Feature","geometry":{"type":"Point","coordinates":[79.86,6.93]},'
            '"properties":{"id":4242,"status":"open"}}',
            200,
          );
        }),
      );

      final url = await notes.createNote(
        const LatLng(6.9314, 79.8654),
        'Missing road',
      );

      expect(sent.method, 'POST');
      expect(
        sent.url.toString(),
        'https://api.openstreetmap.org/api/0.6/notes.json',
      );
      expect(sent.bodyFields['lat'], '6.931400');
      expect(sent.bodyFields['lon'], '79.865400');
      expect(sent.bodyFields['text'], 'Missing road\n\n#LankaMaps');
      expect(url.toString(), 'https://www.openstreetmap.org/note/4242');
    });

    test('dev server note links point at the dev website', () async {
      final notes = OsmNotesService(
        apiBaseUrl: 'https://master.apis.dev.openstreetmap.org',
        client: MockClient(
          (_) async => http.Response('{"properties":{"id":7}}', 200),
        ),
      );
      final url = await notes.createNote(const LatLng(7, 80), 'Test report');
      expect(
        url.toString(),
        'https://master.apis.dev.openstreetmap.org/note/7',
      );
    });

    test('throws on API errors', () async {
      final notes = OsmNotesService(
        apiBaseUrl: 'https://api.openstreetmap.org',
        client: MockClient(
          (_) async => http.Response('Too many requests', 429),
        ),
      );
      expect(() => notes.createNote(const LatLng(7, 80), 'x'), throwsException);
    });
  });

  test('Google Maps directions link', () {
    final uri = googleMapsDirectionsUri(
      destination: const LatLng(6.9314, 79.8654),
      origin: const LatLng(6.919, 79.849),
      mode: TravelMode.bicycle,
    );
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters, {
      'api': '1',
      'origin': '6.919000,79.849000',
      'destination': '6.931400,79.865400',
      'travelmode': 'bicycling',
    });
    expect(
      googleMapsDirectionsUri(
        destination: const LatLng(7, 80),
      ).queryParameters.containsKey('origin'),
      isFalse,
    );
  });

  group('RoutingService options', () {
    Future<Map<String, dynamic>> requestFor(
      TravelMode mode,
      RouteAvoid avoid,
    ) async {
      late Uri uri;
      await RoutingService(
        baseUrl: 'http://gw',
        client: MockClient((req) async {
          uri = req.url;
          return http.Response(valhallaFixture, 200);
        }),
      ).route(fixtureFrom, fixtureTo, mode: mode, avoid: avoid);
      return jsonDecode(uri.queryParameters['json']!) as Map<String, dynamic>;
    }

    test('car avoids tolls, highways and ferries', () async {
      final body = await requestFor(
        TravelMode.car,
        const RouteAvoid(tolls: true, highways: true, ferries: true),
      );
      expect(body['costing_options'], {
        'auto': {'use_ferry': 0.0, 'use_tolls': 0.0, 'use_highways': 0.0},
      });
    });

    test('walking ignores toll and highway settings', () async {
      final body = await requestFor(
        TravelMode.walk,
        const RouteAvoid(tolls: true, highways: true),
      );
      expect(body['costing_options'], {'pedestrian': <String, Object>{}});
    });

    test('parses spoken instructions and shape indexes', () async {
      final route = await fixtureRoute();
      final turn = route.maneuvers[1];
      expect(turn.verbalAlert, 'Turn left onto Ananda Coomaraswamy Mawatha.');
      expect(turn.verbalPre, 'Turn left onto Ananda Coomaraswamy Mawatha.');
      expect(turn.verbalPost, 'Continue for 1.5 kilometers.');
      expect(turn.beginShapeIndex, 2);
      expect(turn.streetNames, ['Ananda Coomaraswamy Mawatha']);
      expect(route.maneuvers.last.isArrival, isTrue);
      expect(route.hasToll, isFalse);
    });
  });
}
