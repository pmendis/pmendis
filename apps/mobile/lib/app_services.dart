import 'package:maplibre_gl/maplibre_gl.dart';

import 'config.dart';
import 'models/place.dart';
import 'navigation/speech.dart';
import 'services/backend.dart';
import 'services/geocoder.dart';
import 'services/osm_notes_service.dart';
import 'services/routing_service.dart';
import 'storage/app_settings.dart';
import 'storage/saved_places.dart';

/// Everything the screens need, created once at startup (and faked in tests).
class AppServices {
  AppServices({
    required this.settings,
    required this.saved,
    RoutingService? routing,
    Geocoder? geocoder,
    OsmNotesService? notes,
    Speech? speech,
  }) : _backend = settings.backend,
       routing =
           routing ?? RoutingService(baseUrl: settings.backend.valhallaUrl),
       _geocoder = _SwitchingGeocoder(
         geocoder ?? settings.backend.createGeocoder(),
       ),
       notes = notes ?? OsmNotesService(apiBaseUrl: osmApiBaseUrl),
       speech = speech ?? TtsSpeech() {
    settings.addListener(_onSettingsChanged);
  }

  final AppSettings settings;
  final SavedPlaces saved;
  final RoutingService routing;
  final _SwitchingGeocoder _geocoder;
  final OsmNotesService notes;
  final Speech speech;
  Backend _backend;

  /// Stays the same object while the service behind it follows the
  /// Map data source setting.
  Geocoder get geocoder => _geocoder;

  Backend get backend => _backend;

  void _onSettingsChanged() {
    final backend = settings.backend;
    if (backend == _backend) return;
    _backend = backend;
    routing.baseUrl = backend.valhallaUrl;
    _geocoder.target = backend.createGeocoder();
  }
}

class _SwitchingGeocoder implements Geocoder {
  _SwitchingGeocoder(this.target);

  Geocoder target;

  @override
  Future<List<Place>> search(String query) => target.search(query);

  @override
  Future<Place?> reverse(LatLng location) => target.reverse(location);
}
