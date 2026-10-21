import 'config.dart';
import 'navigation/speech.dart';
import 'services/geocoding_service.dart';
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
    GeocodingService? geocoder,
    OsmNotesService? notes,
    Speech? speech,
  }) : routing = routing ?? RoutingService(baseUrl: settings.serverUrl),
       geocoder = geocoder ?? GeocodingService(baseUrl: settings.serverUrl),
       notes = notes ?? OsmNotesService(apiBaseUrl: osmApiBaseUrl),
       speech = speech ?? TtsSpeech() {
    settings.addListener(() {
      this.routing.baseUrl = settings.serverUrl;
      this.geocoder.baseUrl = settings.serverUrl;
    });
  }

  final AppSettings settings;
  final SavedPlaces saved;
  final RoutingService routing;
  final GeocodingService geocoder;
  final OsmNotesService notes;
  final Speech speech;
}
