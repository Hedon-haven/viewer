import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_dialog.dart';

class VideoAudioScreen extends StatelessWidget {
  const VideoAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _VideoAudioScreenWidget()),
    );
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
                subtitle:
                    Text("${localStorage.getInt("preferred_video_quality")!}p"),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return OptionsDialog(
                            title: "Theme",
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
                                "${localStorage.getInt("preferred_video_quality")!}p",
                            onSelected: (value) {
                              localStorage.setInt(
                                  "preferred_video_quality",
                                  int.parse(
                                      value.substring(0, value.length - 1)));
                              setState(() {}); // Update the widget
                            });
                      });
                })
          ],
        )));
  }
}
