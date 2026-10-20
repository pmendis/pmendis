import 'package:maplibre_gl/maplibre_gl.dart';

enum TravelMode {
  car('auto', 'Drive'),
  bicycle('bicycle', 'Cycle'),
  walk('pedestrian', 'Walk');

  const TravelMode(this.costing, this.label);

  /// Valhalla costing model name.
  final String costing;
  final String label;
}

class Maneuver {
  const Maneuver({
    required this.instruction,
    required this.lengthKm,
    required this.timeSeconds,
    required this.type,
    this.verbalInstruction,
  });

  final String instruction;

  /// Spoken form announced before the turn, used later for voice guidance.
  final String? verbalInstruction;
  final double lengthKm;
  final double timeSeconds;

  /// Valhalla maneuver type (e.g. 10 = right turn, 15 = left turn, 4 = arrive).
  final int type;
}

class RouteOption {
  const RouteOption({
    required this.shape,
    required this.lengthKm,
    required this.timeSeconds,
    required this.maneuvers,
  });

  final List<LatLng> shape;
  final double lengthKm;
  final double timeSeconds;
  final List<Maneuver> maneuvers;

  LatLngBounds get bounds {
    var south = shape.first.latitude, north = south;
    var west = shape.first.longitude, east = west;
    for (final p in shape) {
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
}
