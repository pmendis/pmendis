import 'package:maplibre_gl/maplibre_gl.dart';

/// A named location: a search result, a tapped point, or the user's position.
class Place {
  const Place({required this.name, required this.location, this.detail});

  final String name;
  final LatLng location;

  /// Secondary line, e.g. the rest of the address.
  final String? detail;

  factory Place.fromCoordinates(LatLng location) => Place(
    name:
        '${location.latitude.toStringAsFixed(5)}, '
        '${location.longitude.toStringAsFixed(5)}',
    location: location,
  );

  @override
  String toString() => 'Place($name, $location)';
}
