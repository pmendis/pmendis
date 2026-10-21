import 'package:maplibre_gl/maplibre_gl.dart';

enum TravelMode {
  car('auto', 'Drive', 'driving'),
  bicycle('bicycle', 'Cycle', 'bicycling'),
  walk('pedestrian', 'Walk', 'walking');

  const TravelMode(this.costing, this.label, this.googleMode);

  /// Valhalla costing model name.
  final String costing;
  final String label;

  /// Google Maps `travelmode` value used when handing off navigation.
  final String googleMode;
}

/// What the router should avoid, from the user's settings.
class RouteAvoid {
  const RouteAvoid({
    this.tolls = false,
    this.highways = false,
    this.ferries = false,
  });

  final bool tolls;
  final bool highways;
  final bool ferries;
}

class Maneuver {
  const Maneuver({
    required this.instruction,
    required this.lengthKm,
    required this.timeSeconds,
    required this.type,
    this.beginShapeIndex = 0,
    this.verbalAlert,
    this.verbalPre,
    this.verbalPost,
    this.streetNames = const [],
  });

  final String instruction;

  /// Spoken well before the maneuver, e.g. "Turn left onto Havelock Road."
  final String? verbalAlert;

  /// Spoken just before the maneuver.
  final String? verbalPre;

  /// Spoken just after the maneuver, e.g. "Continue for 900 meters."
  final String? verbalPost;
  final double lengthKm;
  final double timeSeconds;

  /// Valhalla maneuver type (e.g. 10 = right turn, 15 = left turn, 4 = arrive).
  final int type;

  /// Index into [RouteOption.shape] where this maneuver starts.
  final int beginShapeIndex;
  final List<String> streetNames;

  bool get isArrival => type == 4 || type == 5 || type == 6;
}

class RouteOption {
  const RouteOption({
    required this.shape,
    required this.lengthKm,
    required this.timeSeconds,
    required this.maneuvers,
    this.hasToll = false,
    this.hasHighway = false,
    this.hasFerry = false,
  });

  final List<LatLng> shape;
  final double lengthKm;
  final double timeSeconds;
  final List<Maneuver> maneuvers;
  final bool hasToll;
  final bool hasHighway;
  final bool hasFerry;

  LatLngBounds get bounds => boundsOf(shape);
}

LatLngBounds boundsOf(Iterable<LatLng> points) {
  final first = points.first;
  var south = first.latitude, north = south;
  var west = first.longitude, east = west;
  for (final p in points) {
    if (p.latitude < south) south = p.latitude;
    if (p.latitude > north) north = p.latitude;
    if (p.longitude < west) west = p.longitude;
    if (p.longitude > east) east = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}
