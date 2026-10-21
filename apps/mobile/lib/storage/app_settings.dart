import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
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
  static const _server = 'serverUrl';

  /// The map server (gateway) the app talks to: the user's choice, or the
  /// address the app was built with.
  String get serverUrl => _prefs.getString(_server) ?? apiBaseUrl;

  bool get hasCustomServer => _prefs.containsKey(_server);

  /// Sets the server, or resets to the built-in one when [url] is null.
  set serverUrl(String? url) {
    if (url == null) {
      _prefs.remove(_server);
    } else {
      _prefs.setString(_server, normalizeServerUrl(url)!);
    }
    notifyListeners();
  }

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

/// Cleans up a typed server address ("192.168.1.20:8080/" →
/// "http://192.168.1.20:8080"), or returns null if it isn't a usable URL.
String? normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  while (text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return text;
}
