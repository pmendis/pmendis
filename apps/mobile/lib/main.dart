import 'package:flutter/material.dart';

import 'screens/map_screen.dart';

void main() => runApp(const LankaMapsApp());

class LankaMapsApp extends StatelessWidget {
  const LankaMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2A7BF6);
    return MaterialApp(
      title: 'Lanka Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const MapScreen(),
    );
  }
}
