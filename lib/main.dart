import 'package:flutter/material.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  //setSettings();
  //getSetting();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final ColorScheme colorScheme = brightness == Brightness.dark
        ? ThemeData.dark().colorScheme
        : ThemeData.light().colorScheme;

    final UniversalVideoMetadata testVideoMetadata = UniversalVideoMetadata(
      m3u8Uri: Uri.parse(
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
      title: "Sexy schtuff",
      pluginOrigin: null,
    );

    return MaterialApp(
      title: 'Simple Video Player',
      theme: ThemeData.from(colorScheme: colorScheme),
      home: VideoPlayerScreen(videoMetadata: testVideoMetadata),
    );
  }
}

void setSettings() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('dark_theme', true);
}

void getSetting() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print(prefs.getBool('dark_theme'));
}
