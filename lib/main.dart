import 'package:flutter/material.dart';
import 'package:hedon_viewer/ui/screens/home.dart';

import 'backend/plugin_manager.dart';
import 'backend/shared_prefs_manager.dart';

void main() {
  runApp(const ViewerApp());
  PluginManager();
  SharedPrefsManager();
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final ColorScheme colorScheme = brightness == Brightness.dark
        ? ThemeData.dark().colorScheme
        : ThemeData.light().colorScheme;

    return MaterialApp(
      theme: ThemeData.from(colorScheme: colorScheme),
      home: const HomeScreen(),
    );
  }
}
