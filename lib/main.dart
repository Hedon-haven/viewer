import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/plugin_manager.dart';
import 'package:hedon_viewer/backend/shared_prefs_manager.dart';
import 'package:hedon_viewer/ui/screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences localStorage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  localStorage = await SharedPreferences.getInstance();
  SharedPrefsManager();
  PluginManager();
  runApp(const ViewerApp());
}

class ViewerApp extends StatelessWidget {
  const ViewerApp({Key? key}) : super(key: key);

  static final _defaultLightColorScheme =
      ColorScheme.fromSwatch(primarySwatch: Colors.green);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
      primarySwatch: Colors.green, brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Hedon haven',
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
          useMaterial3: true,
        ),
        themeMode: SharedPrefsManager().getThemeMode(),
        home: const HomeScreen(),
      );
    });
  }
}
