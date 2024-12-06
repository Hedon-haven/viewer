import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/main.dart';
import '/ui/toast_notification.dart';

class LauncherAppearance extends StatefulWidget {
  const LauncherAppearance({super.key});

  @override
  State<LauncherAppearance> createState() => _LauncherAppearanceScreenState();
}

class _LauncherAppearanceScreenState extends State<LauncherAppearance> {
  // the actual default icon is called "stock" everywhere except here
  final List<String> list = ["default", "fake_settings", "reminders"];

  void handleOptionChange(String? value) async {
    if (kDebugMode || kProfileMode) {
      // FIXME: Report bug upstream or fix myself
      ToastMessageShower.showToast(
          "Doesn't work in Debug or Profile versions", context);
      return;
    }
    if (value != null) {
      // show dialogue explaining the option if needed
      if (value != "Hedon haven") {
        await showDialog(
            context: context,
            builder: (BuildContext context) {
              // running setupAppIcon will force the app to quit. Ask user to confirm first
              return AlertDialog(
                  content: Text(
                      value == "Reminders"
                          ? "Create a new reminder called \"Stop concealing\" to exit reminders mode."
                          : "Long press on \"Show signal strength in advanced mode\" to exit GSM Settings mode",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // close popup
                        Navigator.pop(context);
                      },
                      child: const Text("Ok"),
                    )
                  ]);
            });
      }
      setState(() {});
      showDialog(
          context: context,
          builder: (BuildContext context) {
            // running setupAppIcon will force the app to quit. Ask user to confirm first
            return AlertDialog(
                content: Text(
                    "App will now close and can be found again as \"$value\" in the launcher.",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  TextButton(
                    onPressed: () {
                      // close popup
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      // close popup
                      Navigator.pop(context);
                      sharedStorage.setString("app_appearance", value);
                      switch (value) {
                        case "Hedon haven":
                          logger.i("Changing to stock icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "default", iconList: list);
                          break;
                        case "GSM Settings":
                          logger.i("Changing to GSM settings icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "fake_settings", iconList: list);
                          break;
                        case "Reminders":
                          logger.i("Changing to reminders icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "reminders", iconList: list);
                          break;
                      }
                    },
                    child: const Text("Ok",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ]);
          });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("App icon & name"),
        ),
        body: SafeArea(
            child: SingleChildScrollView(
                child: FutureBuilder<String>(
                    // Force non-null
                    future: sharedStorage
                        .getString("app_appearance")
                        .then((value) => value!),
                    builder: (context, snapshot) {
                      // only build when data finished loading
                      if (snapshot.data == null) {
                        return const SizedBox();
                      }
                      return Column(
                        children: [
                          ListTile(
                              title: const Text("Hedon haven"),
                              leading: const CircleAvatar(
                                foregroundImage: AssetImage(
                                    "assets/launcher-icon/stock.png"),
                                backgroundColor: Colors.white,
                              ),
                              trailing: Radio(
                                value: "Hedon haven",
                                groupValue: snapshot.data!,
                                onChanged: handleOptionChange,
                              )),
                          const SizedBox(height: 10),
                          ListTile(
                              title: const Text("GSM Settings"),
                              leading: const CircleAvatar(
                                foregroundImage: AssetImage(
                                    "assets/launcher-icon/fake_settings.png"),
                                backgroundColor: Colors.white,
                              ),
                              trailing: Radio(
                                value: "GSM Settings",
                                groupValue: snapshot.data!,
                                onChanged: handleOptionChange,
                              )),
                          const SizedBox(height: 10),
                          ListTile(
                              title: const Text("Reminders"),
                              leading: const CircleAvatar(
                                foregroundImage: AssetImage(
                                    "assets/launcher-icon/reminders.png"),
                                backgroundColor: Colors.white,
                              ),
                              trailing: Radio(
                                value: "Reminders",
                                groupValue: snapshot.data!,
                                onChanged: handleOptionChange,
                              ))
                        ],
                      );
                    }))));
  }
}
