import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/backend/custom_logger.dart';
import '/backend/managers/database_manager.dart';
import '/backend/managers/icon_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/managers/shared_prefs_manager.dart';
import '/backend/managers/update_manager.dart';
import '/ui/screens/home.dart';
import '/ui/screens/library.dart';
import '/ui/screens/settings/settings_main.dart';
import '/ui/screens/subscriptions.dart';

final SharedPreferencesAsync sharedStorage = SharedPreferencesAsync();
// Store the value here, so that user only sees the warning once per session
bool thirdPartyPluginWarningShown = false;
final logger = Logger(
  printer: BetterSimplePrinter(),
  filter: VariableFilter(),
);
late PackageInfo packageInfo;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.i("Initializing app");
  packageInfo = await PackageInfo.fromPlatform();
  await setDefaultSettings();
  await initDb();
  await PluginManager.discoverAndLoadPlugins();
  IconManager().downloadPluginIcons();
  logger.i("Starting flutter process");
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

  bool updateAvailable = false;
  bool isDownloadingUpdate = false;
  bool updateFailed = false;
  String? latestChangeLog;
  String? updateLink;
  double downloadProgress = 0.0;
  UpdateManager updateManager = UpdateManager();

  int _selectedIndex = 0;
  static List<Widget> screenList = <Widget>[
    const HomeScreen(),
    const SubscriptionsScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future<List<String?>> updateResponseFuture = updateManager.checkForUpdate();
    updateResponseFuture.whenComplete(() async {
      List<String?> updateFuture = await updateResponseFuture;
      updateLink = updateFuture[0];
      latestChangeLog = updateFuture[1];
      if (updateLink != null) {
        setState(() {
          updateAvailable = true;
        });
      }
    });
    updateManager.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    updateManager.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return FutureBuilder<ThemeMode>(
          future: getThemeMode(),
          builder: (context, snapshot) {
            // only build when data finished loading
            if (snapshot.data == null) {
              return const SizedBox();
            }
            return MaterialApp(
              title: 'Hedon haven',
              theme: ThemeData(
                colorScheme: lightColorScheme ?? _defaultLightColorScheme,
              ),
              darkTheme: ThemeData(
                colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
              ),
              themeMode: snapshot.data,
              home: updateAvailable
                  ? AlertDialog(
                      title: const Center(child: Text("Update available")),
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(!isDownloadingUpdate
                            ? updateFailed
                                ? "Update failed, please try again later"
                                : "Please install the update to continue"
                            : "Downloading update..."),
                        const SizedBox(height: 20),
                        latestChangeLog != null &&
                                !isDownloadingUpdate &&
                                !updateFailed
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Latest changelog: "),
                                  const SizedBox(height: 5),
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                      ),
                                      child: Padding(
                                          padding: const EdgeInsets.all(5.0),
                                          child: Text(latestChangeLog!)))
                                ],
                              )
                            : const SizedBox(),
                        isDownloadingUpdate
                            ? LinearProgressIndicator(
                                value: updateManager.downloadProgress)
                            : const SizedBox()
                      ]),
                      actions: <Widget>[
                        !isDownloadingUpdate
                            ? ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    updateAvailable = false;
                                  });
                                },
                                child: Text(updateFailed ? "Ok" : "Cancel"),
                              )
                            : const SizedBox(),
                        !isDownloadingUpdate && !updateFailed
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  // TODO: Fix background color of button
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                onPressed: () async {
                                  if (!isDownloadingUpdate) {
                                    isDownloadingUpdate = true;
                                    logger.i("Starting update");
                                    try {
                                      await updateManager
                                          .downloadAndInstallUpdate(
                                              updateLink!);
                                    } catch (e) {
                                      logger.e("Update failed with: $e");
                                      setState(() {
                                        updateFailed = true;
                                      });
                                    }
                                  }
                                },
                                child: Text("Update and install",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary)),
                              )
                            : const SizedBox()
                      ],
                    )
                  : Scaffold(
                      bottomNavigationBar: NavigationBar(
                          destinations: <Widget>[
                            NavigationDestination(
                              icon: _selectedIndex == 0
                                  ? const Icon(Icons.home)
                                  : const Icon(Icons.home_outlined),
                              label: "Home",
                            ),
                            NavigationDestination(
                              icon: _selectedIndex == 1
                                  ? const Icon(Icons.subscriptions)
                                  : const Icon(Icons.subscriptions_outlined),
                              label: "Subscriptions",
                            ),
                            NavigationDestination(
                              icon: _selectedIndex == 2
                                  ? const Icon(Icons.video_library)
                                  : const Icon(Icons.video_library_outlined),
                              label: "Library",
                            ),
                            NavigationDestination(
                              icon: _selectedIndex == 3
                                  ? const Icon(Icons.settings)
                                  : const Icon(Icons.settings_outlined),
                              label: "Settings",
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
    });
  }
}
