import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/plugin_manager.dart';
import 'package:hedon_viewer/ui/screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';


late SharedPreferences localStorage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  localStorage = await SharedPreferences.getInstance();
  PluginManager();
  runApp(const ViewerApp());
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
