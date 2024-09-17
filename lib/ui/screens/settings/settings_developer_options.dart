import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/custom_logger.dart';
import 'package:hedon_viewer/main.dart';
import 'package:path_provider/path_provider.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/managers/shared_prefs_manager.dart';
import '/ui/toast_notification.dart';
import 'custom_widgets/options_switch.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Developer options"),
        ),
        body: SafeArea(
            child: SizedBox(
                child: Column(
          children: <Widget>[
            ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text("Reset all settings to default"),
                onTap: () {
                  SharedPrefsManager().setDefaultSettings(true);
                  PluginManager.discoverAndLoadPlugins();
                  ToastMessageShower.showToast(
                      "All settings have been reset", context);
                }),
            ListTile(
                leading: const Icon(Icons.storage),
                title: const Text("Delete all databases"),
                onTap: () {
                  // Purge db, then immediately recreate it
                  DatabaseManager.purgeDatabase().then((_) {
                    DatabaseManager.getDb().then((tempDb) => tempDb.close());
                    ToastMessageShower.showToast(
                        "All databases have been deleted", context);
                  });
                }),
            ListTile(
                leading: const Icon(Icons.extension_off),
                title: const Text("Delete all third-party extensions"),
                onTap: () {
                  // delete the whole plugins dir
                  getApplicationSupportDirectory().then((appSupportDir) {
                    Directory("${appSupportDir.path}/plugins")
                        .deleteSync(recursive: true);
                  });
                  PluginManager.discoverAndLoadPlugins();
                  ToastMessageShower.showToast(
                      "All third-party extensions have been deleted", context);
                }),
            OptionsSwitch(
              title: "Enable logging",
              leadingWidget: const Icon(Icons.bug_report),
              switchState:
                  kDebugMode ? true : sharedStorage.getBool("enable_logging")!,
              nonInteractive: kDebugMode,
              onToggled: (newState) {
                sharedStorage.setBool("enable_logging", newState);
                ToastMessageShower.showToast(
                    "Logging ${newState ? "enabled" : "disabled"}", context);
              },
            ),
            ListTile(
                leading: const Icon(Icons.list),
                title: const Text("View current log"),
                onTap: () {
                  getApplicationSupportDirectory().then((appSupportDir) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LogScreen(
                                logText: File(
                                        "${appSupportDir.path}/logs/current.log")
                                    .readAsStringSync())));
                  });
                }),
            ListTile(
                leading: const Icon(Icons.share),
                title: const Text("Export all logs"),
                onTap: () async {
                  try {
                    await BetterSimplePrinter().exportLogs();
                  } catch (e) {
                    ToastMessageShower.showToast(e.toString(), context);
                  }
                })
          ],
        ))));
  }
}

class LogScreen extends StatelessWidget {
  final String logText;

  const LogScreen({super.key, required this.logText});

  @override
  Widget build(BuildContext context) {
    // Split the logText into lines
    final lines = logText.split('\n');

    // Create a list of TextSpan widgets
    final textSpans = lines.map((line) {
      Color color;
      if (line.startsWith('[D]')) {
        color = Colors.white;
      } else if (line.startsWith('[I]')) {
        color = Colors.blue;
      } else if (line.startsWith('[W]')) {
        color = Colors.yellow;
      } else if (line.startsWith('[E]')) {
        color = Colors.red;
      } else {
        color = Colors.white; // Default color
      }

      return TextSpan(
        text: '$line\n',
        style: TextStyle(color: color),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        title: const Text("Current log"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Scrollbar(
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              child: RichText(
                text: TextSpan(children: textSpans),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
