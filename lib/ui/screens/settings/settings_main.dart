import 'package:flutter/material.dart';

import '/main.dart';
import 'settings_about.dart';
import 'settings_appearance.dart';
import 'settings_comments.dart';
import 'settings_developer.dart';
import 'settings_history.dart';
import 'settings_misc.dart';
import 'settings_plugins.dart';
import 'settings_video_audio.dart';

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
                    title: const Text("Comments"),
                    subtitle: const Text("Filters, show hidden/spam comments"),
                    leading: const Icon(Icons.comment),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CommentsScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("History"),
                    subtitle: const Text("Watch & Search history"),
                    leading: const Icon(Icons.history),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HistoryScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("Miscellaneous"),
                    subtitle: const Text("Keyboard private mode"),
                    leading: const Icon(Icons.miscellaneous_services),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MiscScreen()));
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
                  FutureBuilder<bool?>(
                      future: sharedStorage.getBool("enable_dev_options"),
                      builder: (context, snapshot) {
                        // only build when data finished loading
                        if (snapshot.data == null) {
                          return const SizedBox();
                        }
                        return snapshot.data!
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
                            : const SizedBox();
                      })
                ],
              )),
        ));
  }
}
