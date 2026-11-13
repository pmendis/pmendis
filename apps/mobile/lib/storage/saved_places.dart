import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';

enum SavedKind { home, work, favourite }

/// Home, Work, favourites and recent searches, stored on the device only.
class SavedPlaces extends ChangeNotifier {
  SavedPlaces(this._prefs) {
    _home = _read(_homeKey);
    _work = _read(_workKey);
    _favourites = _readList(_favouritesKey);
    _recents = _readList(_recentsKey);
  }

  static const maxRecents = 15;
  static const _homeKey = 'savedHome';
  static const _workKey = 'savedWork';
  static const _favouritesKey = 'savedFavourites';
  static const _recentsKey = 'recentPlaces';

  final SharedPreferences _prefs;
  Place? _home;
  Place? _work;
  late List<Place> _favourites;
  late List<Place> _recents;

  Place? get home => _home;
  Place? get work => _work;
  List<Place> get favourites => List.unmodifiable(_favourites);
  List<Place> get recents => List.unmodifiable(_recents);

  bool get isEmpty =>
      _home == null && _work == null && _favourites.isEmpty && _recents.isEmpty;

  /// How [place] is saved, if at all.
  Set<SavedKind> kindsOf(Place place) => {
    if (_home?.samePlaceAs(place) ?? false) SavedKind.home,
    if (_work?.samePlaceAs(place) ?? false) SavedKind.work,
    if (_favourites.any((p) => p.samePlaceAs(place))) SavedKind.favourite,
  };

  void save(Place place, SavedKind kind) {
    switch (kind) {
      case SavedKind.home:
        _home = place;
        _write(_homeKey, place);
      case SavedKind.work:
        _work = place;
        _write(_workKey, place);
      case SavedKind.favourite:
        _favourites = [
          place,
          ..._favourites.where((p) => !p.samePlaceAs(place)),
        ];
        _writeList(_favouritesKey, _favourites);
    }
    notifyListeners();
  }

  void remove(Place place, SavedKind kind) {
    switch (kind) {
      case SavedKind.home:
        _home = null;
        _prefs.remove(_homeKey);
      case SavedKind.work:
        _work = null;
        _prefs.remove(_workKey);
      case SavedKind.favourite:
        _favourites = _favourites.where((p) => !p.samePlaceAs(place)).toList();
        _writeList(_favouritesKey, _favourites);
    }
    notifyListeners();
  }

  /// Records a place the user picked; most recent first, no duplicates.
  void addRecent(Place place) {
    if (place.isMyLocation || place.isCoordinates) return;
    _recents = [
      place,
      ..._recents.where((p) => !p.samePlaceAs(place)),
    ].take(maxRecents).toList();
    _writeList(_recentsKey, _recents);
    notifyListeners();
  }

  void clearRecents() {
    _recents = [];
    _prefs.remove(_recentsKey);
    notifyListeners();
  }

  Place? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  List<Place> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          Place.fromJson(item as Map<String, Object?>),
      ];
    } catch (_) {
      return [];
    }
  }

  void _write(String key, Place place) =>
      _prefs.setString(key, jsonEncode(place.toJson()));

  void _writeList(String key, List<Place> places) =>
      _prefs.setString(key, jsonEncode([for (final p in places) p.toJson()]));
}
