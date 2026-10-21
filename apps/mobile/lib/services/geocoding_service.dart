import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/place.dart';

/// Client for the Nominatim search API behind the gateway.
class GeocodingService {
  GeocodingService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Gateway address; changes when the user picks another server.
  String baseUrl;
  final http.Client _client;

  Future<List<Place>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/geocode/search').replace(
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'countrycodes': 'lk',
        'limit': '$limit',
        'accept-language': 'en',
      },
    );
    final results = await _getJson(uri) as List;
    return [for (final r in results) _parsePlace(r as Map<String, dynamic>)];
  }

  /// The nearest named place, or null when nothing is close enough.
  Future<Place?> reverse(LatLng location) async {
    final uri = Uri.parse('$baseUrl/geocode/reverse').replace(
      queryParameters: {
        'lat': '${location.latitude}',
        'lon': '${location.longitude}',
        'format': 'jsonv2',
        'zoom': '18',
        'accept-language': 'en',
      },
    );
    final result = await _getJson(uri) as Map<String, dynamic>;
    if (result.containsKey('error')) return null;
    // A country-level match (far from any mapped feature) is not a useful name.
    if (((result['place_rank'] as num?) ?? 30) <= 4) return null;
    final place = _parsePlace(result);
    // Keep the exact tapped point rather than the matched feature's centre.
    return Place(name: place.name, detail: place.detail, location: location);
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Search failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Place _parsePlace(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? '';
    final parts = displayName.split(', ');
    final name = (json['name'] as String?)?.isNotEmpty == true
        ? json['name'] as String
        : parts.first;
    final rest = parts.where((p) => p != name).join(', ');
    return Place(
      name: name,
      detail: rest.isEmpty ? null : rest,
      location: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
    );
  }
}
