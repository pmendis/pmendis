import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/route.dart';

/// Google Maps "directions" link. Opens the Google Maps app when installed
/// (with live traffic and its own voice guidance), otherwise the website.
/// Free, no API key: https://developers.google.com/maps/documentation/urls
Uri googleMapsDirectionsUri({
  required LatLng destination,
  LatLng? origin,
  TravelMode mode = TravelMode.car,
}) {
  String coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (origin != null) 'origin': coords(origin),
    'destination': coords(destination),
    'travelmode': mode.googleMode,
  });
}

Future<bool> openInGoogleMaps({
  required LatLng destination,
  LatLng? origin,
  TravelMode mode = TravelMode.car,
}) => launchUrl(
  googleMapsDirectionsUri(destination: destination, origin: origin, mode: mode),
  mode: LaunchMode.externalApplication,
);

Future<bool> openWebPage(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
