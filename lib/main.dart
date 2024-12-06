import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/backend/custom_logger.dart';
import '/backend/managers/database_manager.dart';
import '/backend/managers/icon_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/managers/shared_prefs_manager.dart';
import '/backend/managers/update_manager.dart';
import '/ui/screens/fake_apps/fake_reminders.dart';
import '/ui/screens/fake_apps/fake_settings.dart';
import '/ui/screens/home.dart';
import '/ui/screens/library.dart';
import '/ui/screens/onboarding/onboarding_welcome.dart';
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

/// This stores the global setting of whether the preview should be hidden
bool hidePreview = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.i("Initializing app");
  packageInfo = await PackageInfo.fromPlatform();
  await setDefaultSettings();
  await initDb();
  await PluginManager.discoverAndLoadPlugins();
  // Icons are not critical to startup -> don't await
  downloadPluginIcons();
  await processArgs();
  logger.i("Starting flutter process");
  runApp(const ViewerApp());
}

Future<void> processArgs() async {
  logger.i("Processing args");
  const skipOnboarding =
      bool.fromEnvironment("SKIP_ONBOARDING", defaultValue: false);
  if (skipOnboarding) {
    logger.w("Skipping onboarding");
    await sharedStorage.setBool("onboarding_completed", true);
  }
  logger.i("Finished processing args");
}

class ViewerApp extends StatefulWidget {
  const ViewerApp({super.key});

  @override
  ViewerAppState createState() => ViewerAppState();

  static ViewerAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ViewerAppState>();
}

class ViewerAppState extends State<ViewerApp> with WidgetsBindingObserver {
  /// Whether the app should stop showing a fake screen
  bool concealApp = true;
  bool updateAvailable = false;
  bool isDownloadingUpdate = false;
  bool updateFailed = false;
  String? latestChangeLog;
  String? updateLink;
  double downloadProgress = 0.0;
  UpdateManager updateManager = UpdateManager();

  /// This controls whether the preview should be currently blocked
  bool blockPreview = false;
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
    // Hide app preview by default
    // The desktops don't support app preview hiding at an OS level
    if (Platform.isAndroid || Platform.isIOS) {
      SecureAppSwitcher.on();
    }
    sharedStorage.getBool("hide_app_preview").then((value) {
      if (!value!) {
        // The desktops don't support app preview hiding at an OS level
        if (Platform.isAndroid || Platform.isIOS) {
          SecureAppSwitcher.off();
        }
      }
      setState(() => hidePreview = value);
    });

    // For detecting app state
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    updateManager.removeListener(() {});
    super.dispose();
  }

  // This is only necessary for desktops, as the mobile platforms have that feature built in
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (hidePreview) {
      logger.i("Lifecycle state changed to $state");
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        logger.i("Lifecycle state is paused or inactive");
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          logger.i("Blurring app");
          setState(() {
            blockPreview = true;
          });
        }
      } else if (state == AppLifecycleState.resumed) {
        logger.i("Lifecycle state is resumed");
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          logger.i("Unblurring app");
          setState(() {
            blockPreview = false;
          });
        }
      }
    }
  }

  void parentStopConcealing() {
    setState(() => concealApp = false);
  }

  void setStateMain() {
    setState(() {});
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
              title: "Hedon haven",
              // Try to use system colors first and fallback to Green
              theme: ThemeData(
                colorScheme: lightColorScheme ??
                    ColorScheme.fromSwatch(primarySwatch: Colors.green),
              ),
              darkTheme: ThemeData(
                colorScheme: darkColorScheme ??
                    ColorScheme.fromSwatch(
                        primarySwatch: Colors.green,
                        brightness: Brightness.dark),
              ),
              themeMode: snapshot.data,
              home: Stack(children: [
                FutureBuilder<bool?>(
                    future: sharedStorage.getBool("onboarding_completed"),
                    builder: (context, snapshot) {
                      // only build when data finished loading
                      if (snapshot.data == null) {
                        return const SizedBox();
                      }
                      return !snapshot.data!
                          ? WelcomeScreen(setStateMain: setStateMain)
                          : FutureBuilder<String?>(
                              future: sharedStorage.getString("app_appearance"),
                              builder: (context, snapshot) {
                                // only build when data finished loading
                                if (snapshot.data == null) {
                                  return const SizedBox();
                                }
                                if (!concealApp) {
                                  logger.i(
                                      "App concealing was disabled, loading default app");
                                  return buildRealApp();
                                }
                                logger.i("App appearance is ${snapshot.data}");
                                switch (snapshot.data!) {
                                  case "GSM Settings":
                                    return FakeSettingsScreen(
                                        parentStopConcealing:
                                            parentStopConcealing);
                                  case "Reminders":
                                    return FakeRemindersScreen(
                                        parentStopConcealing:
                                            parentStopConcealing);
                                  default:
                                    logger.i(
                                        "App concealing is not enabled loading default app");
                                    return buildRealApp();
                                }
                              });
                    }),
                if (blockPreview) ...[
                  Positioned.fill(
                    child: Container(color: Colors.black),
                  ),
                ]
              ]),
            );
          });
    });
  }

  Widget buildRealApp() {
    return updateAvailable
        ? buildUpdateDialogue()
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
            body: screenList.elementAt(_selectedIndex));
  }

  Widget buildUpdateDialogue() {
    return AlertDialog(
      title: const Center(child: Text("Update available")),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(!isDownloadingUpdate
            ? updateFailed
                ? "Update failed, please try again later"
                : "Please install the update to continue"
            : "Downloading update..."),
        const SizedBox(height: 20),
        latestChangeLog != null && !isDownloadingUpdate && !updateFailed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Latest changelog: "),
                  const SizedBox(height: 5),
                  Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Text(latestChangeLog!)))
                ],
              )
            : const SizedBox(),
        isDownloadingUpdate
            ? LinearProgressIndicator(value: updateManager.downloadProgress)
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () async {
                  if (!isDownloadingUpdate) {
                    isDownloadingUpdate = true;
                    logger.i("Starting update");
                    try {
                      await updateManager.downloadAndInstallUpdate(updateLink!);
                    } catch (e) {
                      logger.e("Update failed with: $e");
                      setState(() {
                        updateFailed = true;
                      });
                    }
                  }
                },
                child: Text("Update and install",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary)),
              )
            : const SizedBox()
      ],
    );
  }
}
