import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/app_services.dart';
import 'package:lanka_maps/config.dart';
import 'package:lanka_maps/services/backend.dart';
import 'package:lanka_maps/services/geocoding_service.dart';
import 'package:lanka_maps/services/photon_geocoder.dart';
import 'package:lanka_maps/models/place.dart';
import 'package:lanka_maps/navigation/speech.dart';
import 'package:lanka_maps/models/route.dart';
import 'package:lanka_maps/storage/app_settings.dart';
import 'package:lanka_maps/storage/saved_places.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const museum = Place(
    name: 'Colombo National Museum',
    detail: 'Ward Place',
    location: LatLng(6.9314, 79.8654),
  );
  const temple = Place(
    name: 'Gangaramaya Temple',
    location: LatLng(6.9167, 79.8562),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved places survive a restart', () async {
    final saved = SavedPlaces(await SharedPreferences.getInstance());
    saved.save(museum, SavedKind.home);
    saved.save(temple, SavedKind.favourite);
    saved.addRecent(museum);

    final reloaded = SavedPlaces(await SharedPreferences.getInstance());
    expect(reloaded.home!.name, museum.name);
    expect(reloaded.home!.detail, 'Ward Place');
    expect(reloaded.home!.location.latitude, closeTo(6.9314, 1e-9));
    expect(reloaded.favourites.single.name, temple.name);
    expect(reloaded.recents.single.name, museum.name);
    expect(reloaded.kindsOf(museum), {SavedKind.home});
    expect(reloaded.kindsOf(temple), {SavedKind.favourite});
  });

  test('remove and clear', () async {
    final saved = SavedPlaces(await SharedPreferences.getInstance());
    saved.save(museum, SavedKind.work);
    saved.save(museum, SavedKind.favourite);
    saved.remove(museum, SavedKind.favourite);
    expect(saved.kindsOf(museum), {SavedKind.work});
    saved.remove(museum, SavedKind.work);
    expect(saved.work, isNull);
    saved.addRecent(temple);
    saved.clearRecents();
    expect(saved.isEmpty, isTrue);
  });

  test(
    'recents: newest first, no duplicates, capped, skips unnamed points',
    () async {
      final saved = SavedPlaces(await SharedPreferences.getInstance());
      for (var i = 0; i < 20; i++) {
        saved.addRecent(
          Place(name: 'Place $i', location: LatLng(7, 80 + i / 100)),
        );
      }
      saved.addRecent(Place(name: 'Place 3', location: const LatLng(7, 80.03)));
      saved.addRecent(Place.fromCoordinates(const LatLng(7.1, 80.1)));
      saved.addRecent(Place.myLocation(const LatLng(7.2, 80.2)));

      expect(saved.recents, hasLength(SavedPlaces.maxRecents));
      expect(saved.recents.first.name, 'Place 3');
      expect(saved.recents[1].name, 'Place 19');
      expect(saved.recents.where((p) => p.name == 'Place 3'), hasLength(1));
    },
  );

  test('corrupt stored data is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'savedHome': 'not json',
      'recentPlaces': '[1,2]',
    });
    final saved = SavedPlaces(await SharedPreferences.getInstance());
    expect(saved.home, isNull);
    expect(saved.recents, isEmpty);
  });

  test('settings defaults and persistence', () async {
    final settings = AppSettings(await SharedPreferences.getInstance());
    expect(settings.voiceGuidance, isTrue);
    expect(settings.simulateNavigation, isFalse);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.travelMode, TravelMode.car);

    var notified = 0;
    settings.addListener(() => notified++);
    settings
      ..avoidTolls = true
      ..avoidFerries = true
      ..themeMode = ThemeMode.dark
      ..travelMode = TravelMode.walk
      ..voiceGuidance = false;
    expect(notified, 5);

    final reloaded = AppSettings(await SharedPreferences.getInstance());
    expect(reloaded.avoid.tolls, isTrue);
    expect(reloaded.avoid.highways, isFalse);
    expect(reloaded.avoid.ferries, isTrue);
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.travelMode, TravelMode.walk);
    expect(reloaded.voiceGuidance, isFalse);
  });

  test(
    'map data source: public by default, own server, back to public',
    () async {
      final settings = AppSettings(await SharedPreferences.getInstance());
      expect(settings.backend, const Backend.publicServices());
      expect(settings.ownServerUrl, isNull);

      settings.useOwnServer(' 192.168.1.20:8080/ ');
      expect(
        settings.backend,
        const Backend.ownServer('http://192.168.1.20:8080'),
      );
      expect(
        AppSettings(await SharedPreferences.getInstance()).backend,
        const Backend.ownServer('http://192.168.1.20:8080'),
      );

      settings.usePublicServices();
      expect(settings.backend.isPublic, isTrue);
      // The address is remembered for next time the dialog opens.
      expect(settings.ownServerUrl, 'http://192.168.1.20:8080');
    },
  );

  test('Backend derives service URLs', () {
    const own = Backend.ownServer('https://maps.example.lk');
    expect(
      own.styleUrl(Brightness.light),
      'https://maps.example.lk/styles/light.json',
    );
    expect(
      own.styleUrl(Brightness.dark),
      'https://maps.example.lk/styles/dark.json',
    );
    expect(own.valhallaUrl, 'https://maps.example.lk/valhalla');
    expect(own.createGeocoder(), isA<GeocodingService>());
    expect(own.label, 'https://maps.example.lk');

    const public = Backend.publicServices();
    expect(
      public.styleUrl(Brightness.light),
      publicStyleUrls[Brightness.light],
    );
    expect(public.valhallaUrl, publicValhallaUrl);
    expect(public.createGeocoder(), isA<PhotonGeocoder>());
    expect(public, const Backend.publicServices());
    expect(public, isNot(own));
  });

  test('normalizeServerUrl', () {
    expect(
      normalizeServerUrl('https://maps.example.lk/'),
      'https://maps.example.lk',
    );
    expect(normalizeServerUrl('maps.example.lk'), 'http://maps.example.lk');
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://x'), isNull);
    expect(normalizeServerUrl('http://'), isNull);
  });

  test('services follow a change of map data source', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final services = AppServices(
      settings: settings,
      saved: SavedPlaces(prefs),
      speech: _NoSpeech(),
    );
    expect(services.routing.baseUrl, publicValhallaUrl);
    final geocoder = services.geocoder;

    settings.useOwnServer('https://maps.example.lk');
    expect(
      services.backend,
      const Backend.ownServer('https://maps.example.lk'),
    );
    expect(services.routing.baseUrl, 'https://maps.example.lk/valhalla');
    // Widgets keep their reference; the service behind it changed.
    expect(services.geocoder, same(geocoder));
  });
}

class _NoSpeech implements Speech {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
