import 'package:flutter/material.dart';
import 'package:hedon_viewer/ui/video_player.dart';

void main() {
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

    return MaterialApp(
      title: 'Simple Video Player',
      theme: ThemeData.from(colorScheme: colorScheme),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Video Player'),
      ),
      body: const VideoPlayerWidget(),
    );
  }
}
