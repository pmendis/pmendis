import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Gateway address, e.g. `--dart-define=API_BASE_URL=http://192.168.1.20:8080`.
///
/// Defaults to the local docker compose stack: `10.0.2.2` is how the Android
/// emulator reaches the host machine; everything else uses `localhost`.
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

/// Sri Lanka plus a small margin; the camera and search stay inside it.
final sriLankaBounds = LatLngBounds(
  southwest: const LatLng(5.7, 79.3),
  northeast: const LatLng(10.1, 82.1),
);

const sriLankaCenter = LatLng(7.87, 80.77);
