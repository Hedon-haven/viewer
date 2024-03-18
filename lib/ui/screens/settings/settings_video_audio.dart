import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_dialog.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_switch.dart';

class VideoAudioScreen extends StatelessWidget {
  const VideoAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _VideoAudioScreenWidget();
  }
}

class _VideoAudioScreenWidget extends StatefulWidget {
  @override
  State<_VideoAudioScreenWidget> createState() => _VideoAudioScreenState();
}

class _VideoAudioScreenState extends State<_VideoAudioScreenWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Video & Audio"),
        ),
        body: SafeArea(
            child: Column(
          children: <Widget>[
            ListTile(
                title: const Text('Default resolution'),
                subtitle: Text(
                    "${sharedStorage.getInt("preferred_video_quality")!}p"),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return OptionsDialog(
                            title: "Default resolution",
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
                              sharedStorage.setInt(
                                  "preferred_video_quality",
                                  int.parse(
                                      value.substring(0, value.length - 1)));
                              setState(() {}); // Update the widget
                            });
                      });
                }),
            ListTile(
                title: const Text("Double-tap seek duration"),
                subtitle:
                    Text("${sharedStorage.getInt("seek_duration")!} seconds"),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return OptionsDialog(
                            title: "Double-tap seek duration",
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
                              sharedStorage.setInt(
                                  "seek_duration",
                                  int.parse(
                                      value.substring(0, value.length - 8)));
                              setState(() {});
                            });
                      });
                }),
            OptionsSwitch(
                title: "Start in fullscreen",
                subTitle: "Always start videos in fullscreen",
                switchState: sharedStorage.getBool("start_in_fullscreen")!,
                onSelected: (value) =>
                    sharedStorage.setBool("start_in_fullscreen", value)),
            OptionsSwitch(
                title: "Autoplay",
                subTitle: "Start playback of video as soon as it loads",
                switchState: sharedStorage.getBool("auto_play")!,
                onSelected: (value) =>
                    sharedStorage.setBool("auto_play", value))
          ],
        )));
  }
}
