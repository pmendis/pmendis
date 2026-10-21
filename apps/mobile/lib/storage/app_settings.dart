import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/route.dart';

/// User preferences, persisted on the device.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const _voice = 'voiceGuidance';
  static const _tolls = 'avoidTolls';
  static const _highways = 'avoidHighways';
  static const _ferries = 'avoidFerries';
  static const _simulate = 'simulateNavigation';
  static const _theme = 'themeMode';
  static const _mode = 'travelMode';

  bool get voiceGuidance => _prefs.getBool(_voice) ?? true;
  set voiceGuidance(bool v) => _setBool(_voice, v);

  bool get avoidTolls => _prefs.getBool(_tolls) ?? false;
  set avoidTolls(bool v) => _setBool(_tolls, v);

  bool get avoidHighways => _prefs.getBool(_highways) ?? false;
  set avoidHighways(bool v) => _setBool(_highways, v);

  bool get avoidFerries => _prefs.getBool(_ferries) ?? false;
  set avoidFerries(bool v) => _setBool(_ferries, v);

  /// Always simulate the drive instead of following GPS (demo/testing).
  bool get simulateNavigation => _prefs.getBool(_simulate) ?? false;
  set simulateNavigation(bool v) => _setBool(_simulate, v);

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_theme)] ??
      ThemeMode.system;
  set themeMode(ThemeMode v) {
    _prefs.setString(_theme, v.name);
    notifyListeners();
  }

  /// The last travel mode used, so the app reopens with it.
  TravelMode get travelMode =>
      TravelMode.values.asNameMap()[_prefs.getString(_mode)] ?? TravelMode.car;
  set travelMode(TravelMode v) {
    _prefs.setString(_mode, v.name);
    notifyListeners();
  }

  RouteAvoid get avoid => RouteAvoid(
    tolls: avoidTolls,
    highways: avoidHighways,
    ferries: avoidFerries,
  );

  void _setBool(String key, bool value) {
    _prefs.setBool(key, value);
    notifyListeners();
  }
}
