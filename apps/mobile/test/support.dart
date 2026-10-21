import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/navigation/position_source.dart';
import 'package:lanka_maps/navigation/speech.dart';
import 'package:lanka_maps/services/routing_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Real Valhalla 3.9.1 response: Colombo test grid, auto, alternates=2.
final valhallaFixture = File(
  'test/fixtures/valhalla_route.json',
).readAsStringSync();

const fixtureFrom = LatLng(6.919, 79.849);
const fixtureTo = LatLng(6.937, 79.865);

/// The best route from [valhallaFixture].
Future<RouteOption> fixtureRoute() async {
  final service = RoutingService(
    baseUrl: 'http://gw',
    client: MockClient((_) async => http.Response(valhallaFixture, 200)),
  );
  return (await service.route(fixtureFrom, fixtureTo)).first;
}

class FakeSpeech implements Speech {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

/// Position source driven by the test.
class ManualPositionSource implements PositionSource {
  final _controller = StreamController<LocationFix>();
  bool stopped = false;

  void add(LatLng p, {double accuracy = 5, double? heading}) => _controller.add(
    LocationFix(position: p, accuracy: accuracy, heading: heading),
  );

  @override
  Stream<LocationFix> start() => _controller.stream;

  @override
  Future<void> stop() async {
    stopped = true;
    await _controller.close();
  }
}
