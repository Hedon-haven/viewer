import 'package:flutter/material.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/plugin_manager.dart';

void main() {
  runApp(const MyApp());
  PluginManager();
  SharedPrefsManager();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final ColorScheme colorScheme = brightness == Brightness.dark
        ? ThemeData.dark().colorScheme
        : ThemeData.light().colorScheme;

    return MaterialApp(
      title: 'Simple Video Player',
      theme: ThemeData.from(colorScheme: colorScheme),
      home: const HomeScreen(),
    );
  }
}
