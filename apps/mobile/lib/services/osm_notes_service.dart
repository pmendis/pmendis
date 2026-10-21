import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Posts OpenStreetMap Notes: public, anonymous map problem reports that
/// local volunteer mappers review and fix in OpenStreetMap itself.
class OsmNotesService {
  OsmNotesService({required this.apiBaseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// e.g. https://api.openstreetmap.org (production) or the OSM dev server.
  final String apiBaseUrl;
  final http.Client _client;

  /// Creates a note and returns its public web page.
  Future<Uri> createNote(LatLng location, String text) async {
    final response = await _client
        .post(
          Uri.parse('$apiBaseUrl/api/0.6/notes.json'),
          body: {
            'lat': location.latitude.toStringAsFixed(6),
            'lon': location.longitude.toStringAsFixed(6),
            'text': '$text\n\n#LankaMaps',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(
        'Could not send the report (HTTP ${response.statusCode})',
      );
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final id = (json['properties'] as Map<String, dynamic>)['id'];
    final web = apiBaseUrl.replaceFirst('://api.', '://www.');
    return Uri.parse('$web/note/$id');
  }
}
