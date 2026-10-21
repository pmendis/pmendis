import 'dart:ui' show Brightness;

import 'package:http/http.dart' as http;

import '../config.dart';
import 'geocoder.dart';
import 'geocoding_service.dart';
import 'photon_geocoder.dart';

enum BackendMode { publicServices, ownServer }

/// Where the app gets its map, routes and search from: the free public
/// OpenStreetMap services, or a self-hosted Lanka Maps server (infra/).
class Backend {
  const Backend.publicServices()
    : mode = BackendMode.publicServices,
      serverUrl = null;

  const Backend.ownServer(String url)
    : mode = BackendMode.ownServer,
      serverUrl = url;

  final BackendMode mode;

  /// Gateway address of the own server; null for the public services.
  final String? serverUrl;

  bool get isPublic => mode == BackendMode.publicServices;

  /// MapLibre style for the given theme.
  String styleUrl(Brightness brightness) {
    if (isPublic) return publicStyleUrls[brightness]!;
    final name = brightness == Brightness.dark ? 'dark' : 'light';
    return '$serverUrl/styles/$name.json';
  }

  /// Root of the Valhalla API (`/route` is appended).
  String get valhallaUrl =>
      isPublic ? publicValhallaUrl : '$serverUrl/valhalla';

  Geocoder createGeocoder({http.Client? client}) => isPublic
      ? PhotonGeocoder(baseUrl: publicPhotonUrl, client: client)
      : GeocodingService(baseUrl: '$serverUrl/geocode', client: client);

  String get label => isPublic ? 'Public OpenStreetMap services' : serverUrl!;

  @override
  bool operator ==(Object other) =>
      other is Backend && other.mode == mode && other.serverUrl == serverUrl;

  @override
  int get hashCode => Object.hash(mode, serverUrl);

  @override
  String toString() => 'Backend($label)';
}
