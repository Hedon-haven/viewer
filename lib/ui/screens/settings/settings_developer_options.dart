import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/managers/shared_prefs_manager.dart';
import '/ui/toast_notification.dart';

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
                })
          ],
        ))));
  }
}
