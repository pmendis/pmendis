# Lanka Maps app (Flutter)

Maps, search and turn-by-turn navigation for Sri Lanka, using the backend in
[`../../infra`](../../infra). Runs on Android, iOS and the web.

## Features

- **Map** of Sri Lanka (OpenStreetMap data, light and dark styles)
- **Search** for places, with Home, Work, favourites and recent searches
- **Place details**: tap the map or a search result to get Directions, Save,
  Open in Google Maps, or Report a problem
- **Directions** by car, bicycle or on foot, with up to two alternatives,
  arrival times and a step-by-step list. Avoid tolls, highways or ferries in Settings.
- **Turn-by-turn navigation**:
  - spoken prompts ("In 500 meters, turn left onto …")
  - a following camera and automatic rerouting when you leave the route
  - arrival detection, and it keeps running with the screen off
- **Simulated drive**: when the start isn't your current location, or with
  *Settings → Simulate navigation*, the app drives the route by itself so you
  can try navigation from a desk.
- **Open in Google Maps** hands the trip to Google Maps for live traffic.
  It's free and needs no API key.
- **Report a map problem** posts a public OpenStreetMap Note for volunteer mappers to fix.
  Debug builds post to the OSM *test* server, so trial reports never reach real mappers.
- **Saved places stay on the device.** There are no accounts and no tracking.

## Run

Start the backend first (see the root README), then:

```bash
flutter pub get

flutter run                       # Android emulator (reaches the host at 10.0.2.2:8080)
flutter run -d chrome             # web
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080   # phone on your Wi-Fi
```

Release build against a production server:

```bash
flutter build apk --dart-define=API_BASE_URL=https://maps.example.lk
flutter build ipa --dart-define=API_BASE_URL=https://maps.example.lk
```

Optional `--dart-define=OSM_API_URL=…` overrides where problem reports go.
The default is the OSM test server in debug builds and openstreetmap.org in release builds.

## Code layout

```
lib/
  main.dart, app_services.dart     startup and shared services
  config.dart                      gateway URL, OSM API URL, Sri Lanka bounds
  models/                          Place, RouteOption, Maneuver, TravelMode
  services/                        Valhalla routing, Nominatim search,
                                   OSM Notes, Google Maps hand-off
  navigation/
    geo.dart                       distances, bearings, snapping maths
    route_tracker.dart             snaps GPS to the route; progress, off-route, arrival
    voice_announcer.dart           what to say and when
    navigation_controller.dart     one navigation session: GPS → tracker → voice, rerouting
    position_source.dart           real GPS (background-capable) and simulated drive
    speech.dart                    text-to-speech
  storage/                         settings and saved places (shared_preferences)
  screens/                         map, place picker, saved places, settings, about
  widgets/                         search bar, place sheet, route panel, navigation UI
test/                              unit and widget tests; fixtures are real
                                   Valhalla and Nominatim responses
```

## Test

```bash
flutter analyze
flutter test
```

## Platform notes

- **Android:** navigation runs as a foreground service with a notification.
  Location, foreground-service and notification permissions are declared in
  `android/app/src/main/AndroidManifest.xml`. Debug builds allow plain HTTP to
  the local gateway.
- **iOS:** the `location` and `audio` background modes keep guidance running
  with the screen locked. Location usage strings are in `ios/Runner/Info.plist`.
- **Web:** works in Chrome, Edge and Safari. Background navigation isn't
  possible in a browser.
