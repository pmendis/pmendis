import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Own-server address baked in at build time with
/// `--dart-define=API_BASE_URL=http://192.168.1.20:8080`. Empty (the default)
/// means the app starts on the public services below. The user can change
/// either choice later under Settings → Map data source.
const builtInServerUrl = String.fromEnvironment('API_BASE_URL');

/// Free public OpenStreetMap-based services used when no own server is set.
/// They are run by volunteers for light and personal use; for many users,
/// run your own server (see infra/) instead.
const publicStyleUrls = {
  Brightness.light: 'https://tiles.openfreemap.org/styles/liberty',
  Brightness.dark: 'https://tiles.openfreemap.org/styles/dark',
};
const publicValhallaUrl = 'https://valhalla1.openstreetmap.de';
const publicPhotonUrl = 'https://photon.komoot.io';

/// Sent with requests so the public services can see who is calling, as
/// their usage policies ask.
const appUserAgent = 'LankaMaps/0.3.0 (+https://github.com/pmendis/pmendis)';

/// Sri Lanka plus a small margin; the camera and search stay inside it.
final sriLankaBounds = LatLngBounds(
  southwest: const LatLng(5.7, 79.3),
  northeast: const LatLng(10.1, 82.1),
);

const sriLankaCenter = LatLng(7.87, 80.77);

/// `min_lon,min_lat,max_lon,max_lat` form of [sriLankaBounds].
const sriLankaBbox = '79.3,5.7,82.1,10.1';

/// OpenStreetMap API used for map problem reports. Debug builds post to the
/// OSM test server so trial reports don't reach real mappers.
String get osmApiBaseUrl {
  const fromEnv = String.fromEnvironment('OSM_API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return kReleaseMode
      ? 'https://api.openstreetmap.org'
      : 'https://master.apis.dev.openstreetmap.org';
}
