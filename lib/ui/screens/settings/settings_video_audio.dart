import 'package:flutter/material.dart';

import '/ui/widgets/future_widget.dart';
import '/ui/widgets/options_dialog.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

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
                    FutureWidget<int?>(
                        future: sharedStorage
                            .getInt("media_preferred_video_quality"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsTile(
                              title: "Default resolution",
                              subtitle: "${snapshotData}p",
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
                              selectedOption: "${snapshotData}p",
                              onSelected: (value) {
                                setState(() async {
                                  await sharedStorage.setInt(
                                      "media_preferred_video_quality",
                                      int.parse(value.substring(
                                          0, value.length - 1)));
                                }); // Update the widget
                              });
                        }),
                    FutureWidget<int?>(
                        future: sharedStorage.getInt("media_seek_duration"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsTile(
                              title: "Double-tap seek duration",
                              subtitle: "$snapshotData seconds",
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
                              selectedOption: "$snapshotData seconds",
                              onSelected: (value) {
                                setState(() async {
                                  await sharedStorage.setInt(
                                      "media_seek_duration",
                                      int.parse(value.substring(
                                          0, value.length - 8)));
                                });
                              });
                        }),
                    FutureWidget<bool?>(
                        future:
                            sharedStorage.getBool("media_start_in_fullscreen"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Start in fullscreen",
                              subTitle: "Always start videos in fullscreen",
                              switchState: snapshotData!,
                              onToggled: (value) => sharedStorage.setBool(
                                  "media_start_in_fullscreen", value));
                        }),
                    FutureWidget<bool?>(
                        future: sharedStorage.getBool("media_auto_play"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Autoplay",
                              subTitle:
                                  "Start playback of video as soon as it loads",
                              switchState: snapshotData!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("media_auto_play", value));
                        }),
                    FutureWidget<bool?>(
                        future: sharedStorage
                            .getBool("media_show_progress_thumbnails"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Show video progress thumbnails",
                              subTitle:
                                  "Show little progress thumbnails above the timeline",
                              switchState: snapshotData!,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "media_show_progress_thumbnails", value));
                        })
                  ],
                ))));
  }
}
