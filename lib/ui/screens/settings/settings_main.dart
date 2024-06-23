import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/main.dart';
import '/ui/screens/settings/settings_about.dart';
import '/ui/screens/settings/settings_appearance.dart';
import '/ui/screens/settings/settings_developer_options.dart';
import '/ui/screens/settings/settings_plugins.dart';
import '/ui/screens/settings/settings_video_audio.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: Text("Settings",
              style: Theme.of(context).textTheme.headlineLarge),
        ),
        body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: const Text("Plugins"),
                    subtitle: const Text(
                        "Enable/disable plugins, set plugin options"),
                    leading: const Icon(Icons.extension),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PluginsScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("Appearance"),
                    subtitle: const Text(
                        "Default theme, enable homepage, play previews"),
                    leading: const Icon(Icons.palette),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AppearanceScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("Video & Audio"),
                    subtitle: const Text(
                        "Resolution, seek duration, player behavior"),
                    leading: const Icon(Icons.headphones),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const VideoAudioScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("About"),
                    subtitle: const Text("About application"),
                    leading: const Icon(Icons.info),
                    onTap: () {
                      // The AboutScreen has an option to turn on dev settings -> setState on return to immediately show/hide dev settings
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AboutScreen()))
                          .then((value) => setState(() {}));
                    },
                  ),
                  kDebugMode || sharedStorage.getBool("enable_dev_options")!
                      ? ListTile(
                          title: const Text("Developer options"),
                          subtitle: const Text("Dev/debug options"),
                          leading: const Icon(Icons.data_object),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const DeveloperScreen()));
                          },
                        )
                      : const SizedBox()
                ],
              )),
        ));
  }
}
