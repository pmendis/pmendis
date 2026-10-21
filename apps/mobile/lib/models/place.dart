import 'package:maplibre_gl/maplibre_gl.dart';

/// A named location: a search result, a tapped point, or the user's position.
class Place {
  const Place({
    required this.name,
    required this.location,
    this.detail,
    this.isMyLocation = false,
  });

  final String name;
  final LatLng location;

  /// Secondary line, e.g. the rest of the address.
  final String? detail;

  /// Follows the device's position rather than a fixed point.
  final bool isMyLocation;

  factory Place.fromCoordinates(LatLng location) =>
      Place(name: formatCoordinates(location), location: location);

  factory Place.myLocation(LatLng location) =>
      Place(name: 'Your location', location: location, isMyLocation: true);

  /// Whether this is an unnamed dropped pin.
  bool get isCoordinates => name == formatCoordinates(location);

  bool samePlaceAs(Place other) =>
      name == other.name &&
      (location.latitude - other.location.latitude).abs() < 1e-6 &&
      (location.longitude - other.location.longitude).abs() < 1e-6;

  Map<String, Object?> toJson() => {
    'name': name,
    'detail': detail,
    'lat': location.latitude,
    'lon': location.longitude,
  };

  factory Place.fromJson(Map<String, Object?> json) => Place(
    name: json['name']! as String,
    detail: json['detail'] as String?,
    location: LatLng(
      (json['lat']! as num).toDouble(),
      (json['lon']! as num).toDouble(),
    ),
  );

  @override
  String toString() => 'Place($name, $location)';
}

String formatCoordinates(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
