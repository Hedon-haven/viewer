import 'package:flutter/material.dart';

import '/main.dart';
import 'custom_widgets/options_dialog.dart';
import 'custom_widgets/options_switch.dart';
import 'settings_launcher_appearance.dart';

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
