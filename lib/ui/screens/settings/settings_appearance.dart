import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';
import 'package:lq_dynamic_icon/dynamic_icon.dart';

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
                    DialogTile(
                        title: "Theme",
                        subtitle: sharedStorage.getString("theme_mode")!,
                        options: const [
                          "Follow device theme",
                          "Light theme",
                          "Dark theme"
                        ],
                        selectedOption: sharedStorage.getString("theme_mode")!,
                        onSelected: (value) {
                          sharedStorage.setString("theme_mode", value);
                          // TODO: Fix visual glitch when user returns to previous screen
                          ViewerApp.of(context)?.setState(() {});
                        }),
                    DialogTile(
                        // TODO: Add visualization of the list modes
                        title: "List view mode",
                        subtitle: sharedStorage.getString("list_view")!,
                        options: const ["Card", "Grid", "List"],
                        selectedOption: sharedStorage.getString("list_view")!,
                        onSelected: (value) {
                          setState(() {
                            sharedStorage.setString("list_view", value);
                          });
                        }),
                    OptionsSwitch(
                        title: "Play previews",
                        subTitle: "Play previews on homepage/results page",
                        switchState:
                            sharedStorage.getBool("play_previews_video_list")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "play_previews_video_list", value)),
                    OptionsSwitch(
                        title: "Enable homepage",
                        subTitle: "Enable homepage on app startup",
                        switchState: sharedStorage.getBool("homepage_enabled")!,
                        onToggled: (value) =>
                            sharedStorage.setBool("homepage_enabled", value))
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
  String selectedOption = sharedStorage.getString("app_appearance")!;

  // the actual default icon is called "stock" everywhere except here
  final iconChanger = DynamicIcon(iconList: ["default", "fake_settings", "reminders"]);

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
                      "Restart app to change appearance?", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        selectedOption = value;
                        sharedStorage.setString("app_appearance", value);
                        switch (value) {
                          case "Hedon haven":
                            print("Changing to stock icon");
                            iconChanger.setupAppIcon("default");
                            break;
                          case "GSM Settings":
                            print("Changing to GSM settings icon");
                            iconChanger.setupAppIcon("fake_settings");
                            break;
                          case "Reminders":
                            print("Changing to reminders icon");
                            iconChanger.setupAppIcon("reminders");
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
                child: Column(
          children: [
            ListTile(
                title: const Text("Hedon haven"),
                leading: const CircleAvatar(
                  foregroundImage: AssetImage("assets/launcher-icon/stock.png"),
                  backgroundColor: Colors.white,
                ),
                trailing: Radio(
                  value: "Hedon haven",
                  groupValue: selectedOption,
                  onChanged: handleOptionChange,
                )),
            const SizedBox(height: 10),
            ListTile(
                title: const Text("GSM Settings"),
                leading: const CircleAvatar(
                  foregroundImage:
                      AssetImage("assets/launcher-icon/fake_settings.png"),
                  backgroundColor: Colors.white,
                ),
                trailing: Radio(
                  value: "GSM Settings",
                  groupValue: selectedOption,
                  onChanged: handleOptionChange,
                )),
            const SizedBox(height: 10),
            ListTile(
                title: const Text("Reminders"),
                leading: const CircleAvatar(
                  foregroundImage:
                      AssetImage("assets/launcher-icon/reminders.png"),
                  backgroundColor: Colors.white,
                ),
                trailing: Radio(
                  value: "Reminders",
                  groupValue: selectedOption,
                  onChanged: handleOptionChange,
                ))
          ],
        ))));
  }
}
