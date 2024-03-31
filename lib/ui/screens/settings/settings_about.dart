import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  String returnAppType() {
    print(packageInfo.packageName);
    if (packageInfo.packageName.split(".").last == "debug") {
      return "debug";
    } else if (packageInfo.packageName.split(".").last == "viewer" &&
        packageInfo.packageName.split(".").length == 3) {
      return "release";
    } else if (packageInfo.packageName.split(".").last == "profile") {
      return "profile";
    } else {
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
            ),
            ListTile(
              leading: const Icon(Icons.info),
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
                  // TODO: Show proper bug report screen
                  launchUrl(Uri.parse(
                      "https://github.com/Hedon-Haven/viewer/issues"));
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
                  throw Exception("Donations not yet implemented");
                }),
          ],
        ))));
  }
}
