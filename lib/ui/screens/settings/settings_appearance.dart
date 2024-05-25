import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';

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
