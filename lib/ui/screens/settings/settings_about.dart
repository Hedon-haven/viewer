import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/managers/plugin_manager.dart';
import '/backend/managers/update_manager.dart';
import '/main.dart';
import '/plugins/official_plugins_tracker.dart';
import '/ui/screens/debug_screen.dart';
import '/ui/toast_notification.dart';

class AboutScreen extends StatelessWidget {
  AboutScreen({super.key});

  int devSettingsCounter = 0;
  bool devSettingsEnabled = sharedStorage.getBool("enable_dev_options")!;

  String returnAppType() {
    logger.d(packageInfo.packageName);
    if (packageInfo.packageName.split(".").last == "debug") {
      return "debug";
    } else if (packageInfo.packageName.split(".").last == "viewer" &&
        packageInfo.packageName.split(".").length == 3) {
      return "release";
    } else if (packageInfo.packageName.split(".").last == "profile") {
      return "profile";
    } else {
      // TODO: Add desktop versions
      return "UNKNOWN TYPE; PLEASE REPORT THIS TO THE DEVELOPERS";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("About"),
        ),
        body: SafeArea(
            child: SizedBox(
                child: Column(
          children: <Widget>[
            ListTile(
                leading: const Icon(Icons.abc_outlined),
                title: const Text("App name"),
                subtitle: Text(packageInfo.appName),
                onTap: () {
                  if (devSettingsCounter == 6) {
                    if (devSettingsEnabled) {
                      // disable tester plugin if leaving debug mode
                      PluginManager.disablePlugin(
                          getOfficialPluginByName("tester-official")!);
                    }
                    devSettingsEnabled = !devSettingsEnabled;
                    sharedStorage.setBool(
                        "enable_dev_options", devSettingsEnabled);
                    // reload plugins to show TesterPlugin in release versions too
                    PluginManager.discoverAndLoadPlugins();
                    ToastMessageShower.showToast(
                        "Dev settings ${devSettingsEnabled ? "enabled" : "disabled"}",
                        context);
                    devSettingsCounter = 0;
                  } else {
                    devSettingsCounter++;
                  }
                }),
            ListTile(
              leading: const Icon(Icons.info),
              trailing: ElevatedButton(
                onPressed: () {
                  UpdateManager updateManager = UpdateManager();
                  updateManager.checkForUpdate().then((value) {
                    if (value.first != null) {
                      ToastMessageShower.showToast(
                          "Restart app to update", context);
                    } else {
                      ToastMessageShower.showToast(
                          "No update available", context);
                    }
                  });
                },
                child: const Text("Check for update"),
              ),
              title: const Text("Version"),
              subtitle: Text("${packageInfo.version} - ${returnAppType()}"),
            ),
            ListTile(
                leading: const Icon(Icons.code),
                title: const Text("Source code"),
                // TODO: Update source code link
                subtitle: const Text("https://github.com/Hedon-Haven/viewer"),
                onTap: () {
                  launchUrl(Uri.parse("https://github.com/Hedon-Haven/viewer"));
                }),
            ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text("Report bug"),
                subtitle: const Text(
                    "Long press anything in the app to report a bug"),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const BugReportScreen(debugObject: {})));
                }),
            ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Contributors"),
                subtitle: const Text("View all contributors"),
                onTap: () {
                  launchUrl(Uri.parse(
                      "https://github.com/Hedon-haven/viewer/graphs/contributors"));
                }),
            ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text("Donate"),
                subtitle: const Text("Support the development"),
                onTap: () {
                  // TODO: Add donations
                  ToastMessageShower.showToast("Not implemented yet", context);
                }),
          ],
        ))));
  }
}
