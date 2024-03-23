import 'package:flutter/material.dart';
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
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        title: const Text("Settings"),
      ),
      body: SafeArea(
          child: ListView(
        children: <Widget>[
          ListTile(
            title: const Text("Plugins"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => PluginsScreen()));
            },
          ),
          ListTile(
            title: const Text("Homepage"),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HomepageScreen()));
            },
          ),
          ListTile(
            title: const Text("Appearance"),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AppearanceScreen()));
            },
          ),
          ListTile(
            title: const Text("Video & Audio"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const VideoAudioScreen()));
            },
          ),
        ],
      )),
    );
  }
}
