import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'screens/map_screen.dart';
import 'storage/app_settings.dart';
import 'storage/saved_places.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    LankaMapsApp(
      services: AppServices(
        settings: AppSettings(prefs),
        saved: SavedPlaces(prefs),
      ),
    ),
  );
}

class LankaMapsApp extends StatelessWidget {
  const LankaMapsApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2A7BF6);
    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) => MaterialApp(
        title: 'Lanka Maps',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
        ),
        themeMode: services.settings.themeMode,
        home: MapScreen(services: services),
      ),
    );
  }
}
