import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_dialog.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_switch.dart';

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
                        title: const Text('Theme'),
                        subtitle: Text(sharedStorage.getString("theme_mode")!),
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return OptionsDialog(
                                    title: "Theme",
                                    options: const [
                                      "Follow device theme",
                                      "Light theme",
                                      "Dark theme"
                                    ],
                                    selectedOption:
                                        sharedStorage.getString("theme_mode")!,
                                    onSelected: (value) {
                                      sharedStorage.setString(
                                          "theme_mode", value);
                                      // TODO: Fix visual glitch when user returns to previous screen
                                      ViewerApp.of(context)?.setState(() {});
                                    });
                              });
                        }),
                    OptionsSwitch(
                        title: "Play previews",
                        subTitle: "Play previews on homepage/results page",
                        switchState:
                            sharedStorage.getBool("play_previews_video_list")!,
                        onSelected: (value) => sharedStorage.setBool(
                            "play_previews_video_list", value))
                  ],
                ))));
  }
}
