import 'package:flutter/material.dart';

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
                onTap: () async {
                  await DatabaseManager.purgeDatabase();
                  DatabaseManager.getDb().then((tempDb) => tempDb.close());
                  ToastMessageShower.showToast(
                      "All databases have been deleted", context);
                })
          ],
        ))));
  }
}
