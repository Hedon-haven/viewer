import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/database_manager.dart';
import 'package:hedon_viewer/backend/managers/icon_manager.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/managers/shared_prefs_manager.dart';
import 'package:hedon_viewer/ui/screens/downloads.dart';
import 'package:hedon_viewer/ui/screens/history.dart';
import 'package:hedon_viewer/ui/screens/home.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences sharedStorage;
late PackageInfo packageInfo;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedStorage = await SharedPreferences.getInstance();
  packageInfo = await PackageInfo.fromPlatform();
  SharedPrefsManager();
  PluginManager();
  DatabaseManager();
  IconManager().downloadProviderIcons();
  runApp(const ViewerApp());
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({super.key});

  @override
  ViewerAppState createState() => ViewerAppState();

  static ViewerAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ViewerAppState>();
}

class ViewerAppState extends State<ViewerApp> {
  static final _defaultLightColorScheme =
      ColorScheme.fromSwatch(primarySwatch: Colors.green);
  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
      primarySwatch: Colors.green, brightness: Brightness.dark);

  int _selectedIndex = 0;
  static List<Widget> screenList = <Widget>[
    const HomeScreen(),
    const HistoryScreen(),
    const DownloadsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Hedon haven',
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
        ),
        themeMode: SharedPrefsManager().getThemeMode(),
        home: Scaffold(
            bottomNavigationBar: NavigationBar(
                destinations: <Widget>[
                  NavigationDestination(
                    icon: _selectedIndex == 0
                        ? const Icon(Icons.home)
                        : const Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: _selectedIndex == 1
                        ? const Icon(Icons.history)
                        : const Icon(Icons.history_outlined),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: _selectedIndex == 2
                        ? const Icon(Icons.download)
                        : const Icon(Icons.download_outlined),
                    label: 'Downloads',
                  ),
                  NavigationDestination(
                    icon: _selectedIndex == 3
                        ? const Icon(Icons.settings)
                        : const Icon(Icons.settings_outlined),
                    label: 'Settings',
                  ),
                ],
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                }),
            body: screenList.elementAt(_selectedIndex)),
      );
    });
  }
}
