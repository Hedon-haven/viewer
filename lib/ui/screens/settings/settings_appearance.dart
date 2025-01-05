import 'package:flutter/material.dart';

import '/ui/widgets/future_widget.dart';
import '/ui/widgets/options_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';
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
                    FutureWidget<String?>(
                      future: sharedStorage.getString("theme_mode"),
                      finalWidgetBuilder: (context, snapshotData) {
                        return OptionsTile(
                          title: "Theme",
                          subtitle: snapshotData!,
                          options: const [
                            "Follow device theme",
                            "Light theme",
                            "Dark theme"
                          ],
                          selectedOption: snapshotData,
                          onSelected: (value) async {
                            await sharedStorage.setString("theme_mode", value);
                            setState(() {});
                          },
                        );
                      },
                    ),
                    FutureWidget<String?>(
                        future: sharedStorage.getString("list_view"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsTile(
                              // TODO: Add visualization of the list modes
                              title: "List view mode",
                              subtitle: snapshotData!,
                              options: const ["Card", "Grid", "List"],
                              selectedOption: snapshotData,
                              onSelected: (value) async {
                                await sharedStorage.setString(
                                    "list_view", value);
                                setState(() {});
                              });
                        }),
                    FutureWidget<bool?>(
                        future:
                            sharedStorage.getBool("play_previews_video_list"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Play previews",
                              subTitle:
                                  "Play previews on homepage/results page",
                              switchState: snapshotData!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("play_previews_video_list", value));
                        }),
                    FutureWidget<bool?>(
                        future: sharedStorage.getBool("homepage_enabled"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Enable homepage",
                              subTitle: "Enable homepage on app startup",
                              switchState: snapshotData!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("homepage_enabled", value));
                        })
                  ],
                ))));
  }
}
