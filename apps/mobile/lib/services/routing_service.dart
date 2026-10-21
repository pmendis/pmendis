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

  /// Gateway address; changes when the user picks another server.
  String baseUrl;
  final http.Client _client;

  /// Returns the main route first, followed by up to [alternates] alternatives.
  Future<List<RouteOption>> route(
    LatLng from,
    LatLng to, {
    TravelMode mode = TravelMode.car,
    RouteAvoid avoid = const RouteAvoid(),
    int alternates = 2,
    double? heading,
  }) async {
    final request = {
      'locations': [
        {
          'lat': from.latitude,
          'lon': from.longitude,
          // When rerouting, prefer roads in the direction already travelling.
          if (heading != null) 'heading': heading.round(),
        },
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      'costing': mode.costing,
      'costing_options': {mode.costing: _costingOptions(mode, avoid)},
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

  /// 0 = avoid as far as possible, 0.5 = Valhalla's neutral default.
  static Map<String, Object> _costingOptions(
    TravelMode mode,
    RouteAvoid avoid,
  ) => {
    if (avoid.ferries) 'use_ferry': 0.0,
    if (mode == TravelMode.car && avoid.tolls) 'use_tolls': 0.0,
    if (mode == TravelMode.car && avoid.highways) 'use_highways': 0.0,
  };

  static RouteOption _parseTrip(Map<String, dynamic> trip) {
    final summary = trip['summary'] as Map<String, dynamic>;
    final shape = <LatLng>[];
    final maneuvers = <Maneuver>[];
    for (final leg in trip['legs'] as List) {
      leg as Map<String, dynamic>;
      // Maneuver shape indexes are per leg; offset them into the full shape.
      final offset = shape.length;
      shape.addAll(decodePolyline(leg['shape'] as String));
      for (final m in leg['maneuvers'] as List) {
        m as Map<String, dynamic>;
        maneuvers.add(
          Maneuver(
            instruction: m['instruction'] as String,
            verbalAlert: m['verbal_transition_alert_instruction'] as String?,
            verbalPre: m['verbal_pre_transition_instruction'] as String?,
            verbalPost: m['verbal_post_transition_instruction'] as String?,
            lengthKm: (m['length'] as num).toDouble(),
            timeSeconds: (m['time'] as num).toDouble(),
            type: m['type'] as int,
            beginShapeIndex: offset + ((m['begin_shape_index'] as int?) ?? 0),
            streetNames: [
              for (final n in (m['street_names'] as List?) ?? const [])
                n as String,
            ],
          ),
        );
      }
    }
    // A start and end at the same spot can come back as a single point;
    // keep every route a line so tracking always has a segment.
    if (shape.length == 1) shape.add(shape.first);
    return RouteOption(
      shape: shape,
      lengthKm: (summary['length'] as num).toDouble(),
      timeSeconds: (summary['time'] as num).toDouble(),
      maneuvers: maneuvers,
      hasToll: summary['has_toll'] == true,
      hasHighway: summary['has_highway'] == true,
      hasFerry: summary['has_ferry'] == true,
    );
  }
}
