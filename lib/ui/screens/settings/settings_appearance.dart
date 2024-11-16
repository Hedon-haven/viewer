import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/main.dart';
import '/ui/toast_notification.dart';
import 'custom_widgets/options_dialog.dart';
import 'custom_widgets/options_switch.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Plugins"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    ListTile(
                        title: const Text("Launcher appearance"),
                        subtitle: const Text(
                            "Conceal app icon and name in the launcher"),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const LauncherAppearance()))),
                    FutureBuilder<String?>(
                      future: sharedStorage.getString("theme_mode"),
                      builder: (context, snapshot) {
                        // only build when data finished loading
                        if (snapshot.data == null) {
                          return const SizedBox();
                        }
                        return DialogTile(
                          title: "Theme",
                          subtitle: snapshot.data!,
                          options: const [
                            "Follow device theme",
                            "Light theme",
                            "Dark theme"
                          ],
                          selectedOption: snapshot.data!,
                          onSelected: (value) async {
                            await sharedStorage.setString("theme_mode", value);
                            setState(() {});
                          },
                        );
                      },
                    ),
                    FutureBuilder<String?>(
                        future: sharedStorage.getString("list_view"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return DialogTile(
                              // TODO: Add visualization of the list modes
                              title: "List view mode",
                              subtitle: snapshot.data!,
                              options: const ["Card", "Grid", "List"],
                              selectedOption: snapshot.data!,
                              onSelected: (value) async {
                                await sharedStorage.setString(
                                    "list_view", value);
                                setState(() {});
                              });
                        }),
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("play_previews_video_list"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Play previews",
                              subTitle:
                                  "Play previews on homepage/results page",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("play_previews_video_list", value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("homepage_enabled"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Enable homepage",
                              subTitle: "Enable homepage on app startup",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("homepage_enabled", value));
                        })
                  ],
                ))));
  }
}

class LauncherAppearance extends StatefulWidget {
  const LauncherAppearance({super.key});

  @override
  State<LauncherAppearance> createState() => _LauncherAppearanceScreenState();
}

class _LauncherAppearanceScreenState extends State<LauncherAppearance> {
  // the actual default icon is called "stock" everywhere except here
  final List<String> list = ["default", "fake_settings", "reminders"];

  void handleOptionChange(String? value) {
    if (value != null) {
      setState(() {
        if (kDebugMode || kProfileMode) {
          // FIXME: Report bug upstream or fix myself
          ToastMessageShower.showToast(
              "Doesn't work in Debug or Profile mode", context);
          return;
        }
        showDialog(
            context: context,
            builder: (BuildContext context) {
              // running setupAppIcon will force the app to quit. Ask user to confirm first
              return AlertDialog(
                  content: const Text(
                      "App will now close and can be found again under the selected icon and name.",
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
      });
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
