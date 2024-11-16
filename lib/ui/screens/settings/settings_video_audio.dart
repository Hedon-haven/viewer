import 'package:flutter/material.dart';

import '/main.dart';
import 'custom_widgets/options_dialog.dart';
import 'custom_widgets/options_switch.dart';

class VideoAudioScreen extends StatefulWidget {
  const VideoAudioScreen({super.key});

  @override
  State<VideoAudioScreen> createState() => _VideoAudioScreenState();
}

class _VideoAudioScreenState extends State<VideoAudioScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Video & Audio"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    DialogTile(
                        title: "Default resolution",
                        subtitle:
                            "${sharedStorage.getInt("preferred_video_quality")!}p",
                        options: const [
                          "144p",
                          "240p",
                          "360p",
                          "480p",
                          "720p",
                          "1080p",
                          "1440p",
                          "2160p"
                        ],
                        selectedOption:
                            "${sharedStorage.getInt("preferred_video_quality")!}p",
                        onSelected: (value) {
                          setState(() {
                            sharedStorage.setInt(
                                "preferred_video_quality",
                                int.parse(
                                    value.substring(0, value.length - 1)));
                          }); // Update the widget
                        }),
                    DialogTile(
                        title: "Double-tap seek duration",
                        subtitle:
                            "${sharedStorage.getInt("seek_duration")!} seconds",
                        options: const [
                          "5 seconds",
                          "10 seconds",
                          "15 seconds",
                          "20 seconds",
                          "25 seconds",
                          "30 seconds",
                          "60 seconds",
                          "120 seconds"
                        ],
                        selectedOption:
                            "${sharedStorage.getInt("seek_duration")!} seconds",
                        onSelected: (value) {
                          setState(() {
                            sharedStorage.setInt(
                                "seek_duration",
                                int.parse(
                                    value.substring(0, value.length - 8)));
                          });
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("start_in_fullscreen"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Start in fullscreen",
                              subTitle: "Always start videos in fullscreen",
                              switchState: snapshot.data!,
                              onToggled: (value) => sharedStorage.setBool(
                                  "start_in_fullscreen", value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("auto_play"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Autoplay",
                              subTitle:
                                  "Start playback of video as soon as it loads",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("auto_play", value));
                        }),
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("show_progress_thumbnails"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Show video progress thumbnails",
                              subTitle:
                                  "Show little progress thumbnails above the timeline",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("show_progress_thumbnails", value));
                        })
                  ],
                ))));
  }
}
