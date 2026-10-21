import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../config.dart';
import '../models/place.dart';
import 'geocoder.dart';
import 'http_headers.dart';

/// Client for a Photon server (https://github.com/komoot/photon), the
/// OpenStreetMap geocoder built for search-as-you-type. Used with the public
/// instance when the app has no own server.
class PhotonGeocoder implements Geocoder {
  PhotonGeocoder({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<List<Place>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/api').replace(
      queryParameters: {
        'q': q,
        'lang': 'en',
        'limit': '$limit',
        'bbox': sriLankaBbox,
      },
    );
    return [for (final f in await _features(uri)) _parse(f)];
  }

  @override
  Future<Place?> reverse(LatLng location) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(
      queryParameters: {
        'lat': '${location.latitude}',
        'lon': '${location.longitude}',
        'lang': 'en',
        'limit': '1',
      },
    );
    final features = await _features(uri);
    if (features.isEmpty) return null;
    final place = _parse(features.first);
    // Keep the exact tapped point rather than the matched feature's centre.
    return Place(name: place.name, detail: place.detail, location: location);
  }

  Future<List<Map<String, dynamic>>> _features(Uri uri) async {
    final response = await _client
        .get(uri, headers: apiHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Search failed (HTTP ${response.statusCode})');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final f in (json['features'] as List?) ?? const [])
        f as Map<String, dynamic>,
    ];
  }

  /// Photon returns GeoJSON features whose properties hold the address parts.
  static Place _parse(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final coords =
        (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    String? prop(String key) {
      final v = props[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final street = [?prop('street'), ?prop('housenumber')].join(' ');
    final name =
        prop('name') ??
        (street.isNotEmpty ? street : null) ??
        prop('city') ??
        prop('county') ??
        'Unnamed place';
    final parts = <String>[];
    for (final part in [
      street,
      ?prop('district'),
      ?prop('city'),
      ?prop('county'),
      ?prop('state'),
      ?prop('country'),
    ]) {
      if (part.isNotEmpty && part != name && !parts.contains(part)) {
        parts.add(part);
      }
    }
    return Place(
      name: name,
      detail: parts.isEmpty ? null : parts.join(', '),
      location: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
    );
  }
}
