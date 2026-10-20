import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/route.dart';
import 'polyline.dart';

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the Valhalla `/route` API behind the gateway.
class RoutingService {
  RoutingService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Returns the main route first, followed by up to [alternates] alternatives.
  Future<List<RouteOption>> route(
    LatLng from,
    LatLng to, {
    TravelMode mode = TravelMode.car,
    int alternates = 2,
  }) async {
    final request = {
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      'costing': mode.costing,
      'alternates': alternates,
      'directions_options': {'units': 'kilometers', 'language': 'en-US'},
    };
    // GET keeps the request "simple" so browsers skip the CORS preflight.
    final uri = Uri.parse(
      '$baseUrl/valhalla/route',
    ).replace(queryParameters: {'json': jsonEncode(request)});

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw RoutingException('Routing server unreachable ($e)');
    }

    final Map<String, dynamic> body;
    try {
      body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw RoutingException('Routing failed (HTTP ${response.statusCode})');
    }
    if (response.statusCode != 200) {
      throw RoutingException(
        (body['error'] as String?) ??
            'Routing failed (HTTP ${response.statusCode})',
      );
    }

    return [
      _parseTrip(body['trip'] as Map<String, dynamic>),
      for (final alt in (body['alternates'] as List?) ?? const [])
        _parseTrip(
          (alt as Map<String, dynamic>)['trip'] as Map<String, dynamic>,
        ),
    ];
  }

  static RouteOption _parseTrip(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>;
    final shape = <LatLng>[];
    final maneuvers = <Maneuver>[];
    for (final leg in trip['legs'] as List) {
      leg as Map<String, dynamic>;
      shape.addAll(decodePolyline(leg['shape'] as String));
      for (final m in leg['maneuvers'] as List) {
        m as Map<String, dynamic>;
        maneuvers.add(
          Maneuver(
            instruction: m['instruction'] as String,
            verbalInstruction:
                m['verbal_pre_transition_instruction'] as String?,
            lengthKm: (m['length'] as num).toDouble(),
            timeSeconds: (m['time'] as num).toDouble(),
            type: m['type'] as int,
          ),
        );
      }
    }
    return RouteOption(
      shape: shape,
      lengthKm: (summary['length'] as num).toDouble(),
      timeSeconds: (summary['time'] as num).toDouble(),
      maneuvers: maneuvers,
    );
  }
}
