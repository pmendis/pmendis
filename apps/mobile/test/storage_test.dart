import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanka_maps/models/place.dart';
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
}
