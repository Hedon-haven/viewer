import 'package:flutter/material.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_about.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_appearance.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_homepage.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_plugins.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_video_audio.dart';

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
              child: ListView(
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
                    title: const Text("Homepage"),
                    subtitle: const Text("Default provider settings"),
                    leading: const Icon(Icons.home),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HomepageScreen()));
                    },
                  ),
                  ListTile(
                    title: const Text("Appearance"),
                    subtitle: const Text("Default theme, play previews"),
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
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AboutScreen()));
                    },
                  )
                ],
              )),
        ));
  }
}
