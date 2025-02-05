import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '/services/database_manager.dart';
import '/services/icon_manager.dart';
import '/services/plugin_manager.dart';
import '/services/shared_prefs_manager.dart';
import '/services/update_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/utils/update_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/custom_logger.dart';
import '/utils/global_vars.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  void downloadCustomUpdate(BuildContext context) async {
    String? tag;
    String? link;

    TextEditingController textController = TextEditingController();
    tag = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            title: Text("Set custom update tag",
                style: Theme.of(context).textTheme.titleMedium),
            content: TextField(
                controller: textController,
                decoration: InputDecoration(hintText: "e.g. v0.3.15")),
            actions: [
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface),
                child: Text("Cancel",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary),
                child: Text("Next",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary)),
                onPressed: () => Navigator.of(context).pop(textController.text),
              )
            ]);
      },
    );

    if (tag?.isEmpty ?? true) {
      showToast("Tag cannot be empty", context);
      return;
    }

    textController.clear();
    link = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            title: Text(
                "Set custom link (leave empty for default). The updater"
                " will use 'link/tag/os-arch.extension to download. "
                "E.g. https://download.hedon-haven.top/v0.3.14/android-arm64.apk'"
                "\n\nDO NOT ADD A TRAILING /",
                style: Theme.of(context).textTheme.titleSmall),
            content: TextField(
                controller: textController,
                decoration: InputDecoration(
                    hintText:
                        "E.g. https://github.com/myuser/myrepo/releases/download "
                        "(without / at the end!)")),
            actions: [
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface),
                child: Text("Cancel",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                // Make sure to reset tag as well to prevent update
                onPressed: () => {tag = null, Navigator.of(context).pop(null)},
              ),
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary),
                child: Text("Attempt update",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary)),
                onPressed: () => Navigator.of(context).pop(textController.text),
              )
            ]);
      },
    );

    if (tag != null) {
      UpdateManager updateManager = UpdateManager();
      updateManager.latestTag = tag;
      if (link?.isNotEmpty ?? false) {
        updateManager.downloadLink = link!;
      }
      updateManager.latestChangeLog =
          "Keep in mind that on OS' that check signatures, this might not work "
          "with the official version.";
      showUpdateDialog(updateManager, context);
    }
  }

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
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: <Widget>[
                        ListTile(
                            leading: const Icon(Icons.settings_backup_restore),
                            title: const Text("Reset all settings to default"),
                            onTap: () async {
                              await setDefaultSettings(true);
                              PluginManager.discoverAndLoadPlugins();
                              showToast(
                                  "All settings have been reset", context);
                            }),
                        ListTile(
                            leading: const Icon(Icons.storage),
                            title: const Text("Delete all databases"),
                            onTap: () async {
                              // Purge db, then immediately recreate it
                              await purgeDatabase();
                              await initDb();
                              showToast(
                                  "All databases have been deleted", context);
                            }),
                        ListTile(
                            leading: const Icon(Icons.extension_off),
                            title:
                                const Text("Delete all third-party extensions"),
                            onTap: () async {
                              // delete the whole plugins dir
                              Directory appSupportDir =
                                  await getApplicationSupportDirectory();
                              await Directory("${appSupportDir.path}/plugins")
                                  .delete(recursive: true);
                              await PluginManager.discoverAndLoadPlugins();
                              showToast(
                                  "All third-party extensions have been deleted",
                                  context);
                            }),
                        ListTile(
                            leading: const Icon(Icons.cached),
                            title: const Text("Refresh icon cache"),
                            onTap: () async {
                              // delete the whole plugins dir
                              await downloadPluginIcons(force: true);
                              showToast(
                                  "Icon cache has been refreshed", context);
                            }),
                        FutureBuilder<bool?>(
                            future:
                                sharedStorage.getBool("general_enable_logging"),
                            builder: (context, snapshot) {
                              return OptionsSwitch(
                                title: "Enable logging",
                                leadingWidget: const Icon(Icons.bug_report),
                                switchState:
                                    kDebugMode ? true : snapshot.data ?? false,
                                nonInteractive: kDebugMode,
                                onToggled: (newState) async {
                                  await sharedStorage.setBool(
                                      "general_enable_logging", newState);
                                  showToast("Restarting app to apply changes",
                                      context);
                                  showToast(
                                      "Logging ${newState ? "enabled" : "disabled"}",
                                      context);
                                },
                              );
                            }),
                        ListTile(
                            leading: const Icon(Icons.list),
                            title: const Text("View current log"),
                            onTap: () {
                              getApplicationSupportDirectory()
                                  .then((appSupportDir) {
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
                                showToast(e.toString(), context);
                              }
                            }),
                        ListTile(
                          leading: const Icon(Icons.update),
                          title: const Text("Install custom update"),
                          onTap: () => downloadCustomUpdate(context),
                        )
                      ],
                    )))));
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
