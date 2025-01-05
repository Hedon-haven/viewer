import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/utils/custom_logger.dart';
import '/services/database_manager.dart';
import '/services/icon_manager.dart';
import '/services/plugin_manager.dart';
import '/services/shared_prefs_manager.dart';
import '/services/update_manager.dart';
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
  const resetSettings =
      bool.fromEnvironment("RESET_SETTINGS", defaultValue: false);
  if (resetSettings) {
    logger.w("Resetting settings");
    setDefaultSettings(true);
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
  String? failReason;
  String? latestChangeLog;
  String? latestTag;
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

    performUpdate();
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
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          logger.d("Blurring app");
          setState(() {
            blockPreview = true;
          });
        }
      } else if (state == AppLifecycleState.resumed) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          logger.d("Unblurring app");
          setState(() {
            blockPreview = false;
          });
        }
      }
    }
  }

  void performUpdate() async {
    // This is for showing the download progress
    updateManager.addListener(() => setState(() {}));
    try {
      List<String?> updateFuture = await updateManager.checkForUpdate();
      latestTag = updateFuture[0];
      latestChangeLog = updateFuture[1];
      if (latestTag != null) {
        setState(() => updateAvailable = true);
      }
    } catch (e, stacktrace) {
      logger.e("Error checking for app update: $e\n$stacktrace");
      ToastMessageShower.showToast(
          "Error checking for app update: $e", context);
    }
  }

  void parentStopConcealing() {
    setState(() => concealApp = false);
  }

  void setStateMain() {
    logger.d("setState called from child");
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
                              future: sharedStorage
                                  .getString("launcher_appearance"),
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
    return Builder(builder: (context) {
      return Scaffold(
          body: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Center(child: Text("Update available")),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: !updateFailed
                  ? const EdgeInsets.only(bottom: 20)
                  : EdgeInsets.zero,
              child: Text(
                  updateFailed
                      ? "Update failed due to $failReason\n\nPlease try again later."
                      : isDownloadingUpdate
                          ? "Downloading update..."
                          : "Please install the update to continue",
                  style: Theme.of(context).textTheme.titleMedium)),
          if (latestChangeLog != null &&
              !isDownloadingUpdate &&
              !updateFailed) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Latest changelog for $latestTag: ",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Text(latestChangeLog!,
                            style: Theme.of(context).textTheme.bodySmall)))
              ],
            )
          ],
          if (isDownloadingUpdate && !updateFailed) ...[
            LinearProgressIndicator(value: updateManager.downloadProgress)
          ]
        ]),
        actions: <Widget>[
          // This row is needed for the spacer to work
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            if (!isDownloadingUpdate || updateFailed) ...[
              ElevatedButton(
                onPressed: () => setState(() => updateAvailable = false),
                child: Text(updateFailed ? "Ok" : "Install later"),
              ),
              if (!updateFailed) ...[
                Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // TODO: Fix background color of button
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () async {
                    if (!isDownloadingUpdate) {
                      setState(() => isDownloadingUpdate = true);
                      logger.i("Starting update");
                      try {
                        await updateManager
                            .downloadAndInstallUpdate(latestTag!);
                      } catch (e, stacktrace) {
                        logger.e("Update failed with: $e\n$stacktrace");
                        setState(() {
                          updateFailed = true;
                          failReason = e.toString();
                        });
                      }
                    }
                  },
                  child: Text("Update and install",
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary)),
                )
              ]
            ]
          ])
        ],
      ));
    });
  }
}
