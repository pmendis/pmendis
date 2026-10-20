# Lanka Maps app (Flutter)

Map, search and A→B routing for Sri Lanka, using the backend in [`../../infra`](../../infra).

## Run

Start the backend first (see the root README), then:

```bash
flutter pub get

# Android emulator: reaches the host's gateway at 10.0.2.2:8080 by default
flutter run

# Chrome
flutter run -d chrome

# A real phone on the same Wi-Fi: point it at your computer's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

## How to use it

- **Search** for a place, or **tap the map** to set the destination.
- The start is **your location** when location permission is granted.
  Otherwise the first tap sets the start. **Long-press** the map at any time
  to move the start.
- Pick **Drive / Cycle / Walk**, choose between the best route and up to two
  alternatives, and open **Steps** for turn-by-turn instructions.

## Code layout

```
lib/
  config.dart                  gateway URL, Sri Lanka bounds
  models/                      Place, RouteOption, Maneuver, TravelMode
  services/routing_service.dart    Valhalla /route client
  services/geocoding_service.dart  Nominatim search + reverse client
  services/polyline.dart           encoded polyline decoder (precision 6)
  screens/map_screen.dart      map, route drawing, selection logic
  widgets/                     search box, route panel
test/                          unit tests against real Valhalla/Nominatim responses
```

## Test

```bash
flutter analyze
flutter test
```
