import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/route.dart';
import '../services/backend.dart';

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
  static const _backend = 'backendMode';

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

  /// Where map, routes and search come from. Until the user chooses, a build
  /// with a baked-in server address uses it; otherwise the public services.
  Backend get backend {
    final mode = _prefs.getString(_backend);
    final url = _prefs.getString(_server);
    if (mode == 'own' && url != null) return Backend.ownServer(url);
    if (mode == 'public') return const Backend.publicServices();
    return builtInServerUrl.isEmpty
        ? const Backend.publicServices()
        : const Backend.ownServer(builtInServerUrl);
  }

  /// The own-server address to offer in the settings dialog, if any.
  String? get ownServerUrl =>
      _prefs.getString(_server) ??
      (builtInServerUrl.isEmpty ? null : builtInServerUrl);

  void usePublicServices() {
    _prefs.setString(_backend, 'public');
    notifyListeners();
  }

  /// [url] must already be valid; see [normalizeServerUrl].
  void useOwnServer(String url) {
    _prefs.setString(_server, normalizeServerUrl(url)!);
    _prefs.setString(_backend, 'own');
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
