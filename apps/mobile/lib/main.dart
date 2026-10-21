import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'screens/map_screen.dart';
import 'storage/app_settings.dart';
import 'storage/saved_places.dart';

Future<void> main() async {
  // Startup progress is logged so a stuck start shows up in `adb logcat`.
  debugPrint('Lanka Maps: starting');
  WidgetsFlutterBinding.ensureInitialized();
  _reportErrors();

  // Anything that fails before runApp leaves Android on the splash screen
  // forever, so startup failures are shown on screen instead.
  final LankaMapsApp app;
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 10),
    );
    app = LankaMapsApp(
      services: AppServices(
        settings: AppSettings(prefs),
        saved: SavedPlaces(prefs),
      ),
    );
  } catch (error, stack) {
    debugPrint('Lanka Maps failed to start: $error\n$stack');
    runApp(StartupErrorApp(error: error, stack: stack));
    return;
  }
  debugPrint('Lanka Maps: settings loaded, showing the map screen');
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => debugPrint('Lanka Maps: first frame drawn'),
  );
}

/// Logs uncaught errors (visible with `adb logcat`) and shows build errors
/// as readable text rather than a blank grey box in release builds.
void _reportErrors() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      'Lanka Maps error: ${details.exceptionAsString()}\n${details.stack}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Lanka Maps uncaught error: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => Material(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Something went wrong:\n${details.exceptionAsString()}'),
    ),
  );
}

class LankaMapsApp extends StatelessWidget {
  const LankaMapsApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) => MaterialApp(
        title: 'Lanka Maps',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: services.settings.themeMode,
        home: MapScreen(services: services),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) =>
    ThemeData(colorSchemeSeed: const Color(0xFF2A7BF6), brightness: brightness);

/// Shown instead of the app when startup fails, with the error so it can be
/// reported.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    final details = '$error\n\n$stack';
    return MaterialApp(
      title: 'Lanka Maps',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('Lanka Maps could not start')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Please send this message to the developers. Reinstalling the '
              'app or clearing its storage may help.',
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) => FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: details));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copied')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy details'),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              details,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
