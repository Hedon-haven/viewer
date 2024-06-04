import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/video_screen/player_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:window_manager/window_manager.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  State<VideoPlayerScreen> createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool showControls = false;

  VideoPlayerWidget? videoPlayerWidget;
  Timer? hideControlsTimer;
  bool isFullScreen = false;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];
  UniversalVideoMetadata videoMetadata = UniversalVideoMetadata(
      videoID: 'none',
      m3u8Uris: {},
      title: List<String>.filled(10, 'title').join(), // long string
      provider: null);

  @override
  void initState() {
    super.initState();

    widget.videoMetadata.whenComplete(() async {
      videoMetadata = await widget.videoMetadata;
      setState(() {
        isLoadingMetadata = false;
      });
    });
  }

  void toggleFullScreen() {
    // the windowManager is just for desktop. It wont interfere with mobile
    isFullScreen = !isFullScreen;
    if (isFullScreen) {
      windowManager.setFullScreen(true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      AutoOrientation.landscapeAutoMode(forceSensor: true);
    } else {
      windowManager.setFullScreen(false);
      // TODO: Get rid of visual bug due to system not resizing quick enough
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      AutoOrientation.portraitAutoMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: PopScope(
                // only allow pop if not in fullscreen
                canPop: !isFullScreen,
                onPopInvoked: (goingToPop) {
                  print("Pop invoked, goingToPop: $goingToPop");
                  // immediately stop video if popping
                  if (goingToPop) {
                    // FIXME: Stop video immediately on pop
                    // controller.pause();
                  }
                  // restore upright orientation
                  if (isFullScreen) {
                    toggleFullScreen();
                  }
                },
                child: Skeletonizer(
                    enabled: isLoadingMetadata,
                    child: Column(children: <Widget>[
                      SizedBox(
                          height: MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? MediaQuery.of(context).size.height
                              : MediaQuery.of(context).size.width * 9 / 16,
                          child: Skeleton.shade(
                              child: isLoadingMetadata
                                  // to show a skeletonized box, display a container with a color
                                  // Does NOT work if the container has no color
                                  ? Container(color: Colors.black)
                                  : VideoPlayerWidget(
                                      videoMetadata: videoMetadata,
                                      toggleFullScreen: toggleFullScreen))),
                      // only show the following widgets if not in fullscreen
                      if (!isFullScreen) ...[
                        Column(children: <Widget>[
                          // make sure the text element takes up the whole available space
                          SizedBox(
                              width: double.infinity,
                              child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8, left: 10, right: 10),
                                  child: Text(videoMetadata.title,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2))),
                        ])
                      ]
                    ])))));
  }
}

// Browser button:
// OverlayWidget(
//                                   showControls: showControls,
//                                   child: IconButton(
//                                     color: Colors.white,
//                                     icon: const Icon(Icons.open_in_browser),
//                                     onPressed: () async {
//                                       await launchUrl(Uri.parse(videoMetadata
//                                               .pluginOrigin!
//                                               .videoEndpoint +
//                                           videoMetadata.videoID));
//                                     },
//                                   ))
