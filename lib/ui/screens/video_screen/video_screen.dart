import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/ui/toast_notification.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:window_manager/window_manager.dart';

import '/backend/universal_formats.dart';
import '/ui/screens/video_screen/player_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  State<VideoPlayerScreen> createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool showControls = false;

  VideoPlayerWidget? videoPlayerWidget;
  List<Uint8List>? progressThumbnails;
  Timer? hideControlsTimer;
  bool isFullScreen = false;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  bool descriptionExpanded = false;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];
  UniversalVideoMetadata videoMetadata = UniversalVideoMetadata(
      videoID: 'none',
      m3u8Uris: {},
      title: List<String>.filled(10, 'title').join(), // long string
      plugin: null);

  @override
  void initState() {
    super.initState();

    widget.videoMetadata.whenComplete(() async {
      videoMetadata = await widget.videoMetadata;
      setState(() {
        isLoadingMetadata = false;
      });

      // Update screen after thumbnails are loaded
      videoMetadata.plugin!
          .getProgressThumbnails(videoMetadata.videoID, videoMetadata.rawHtml)
          .then((value) {
        setState(() => progressThumbnails = value);
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
    TextStyle mediumTextStyle = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(color: Theme.of(context).colorScheme.onSurface);
    return Scaffold(
        body: SafeArea(
            child: PopScope(
                // only allow pop if not in fullscreen
                canPop: !isFullScreen,
                onPopInvoked: (goingToPop) {
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
                                      progressThumbnails: progressThumbnails,
                                      toggleFullScreen: toggleFullScreen,
                                      isFullScreen: isFullScreen))),
                      // only show the following widgets if not in fullscreen
                      if (!isFullScreen) ...[
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // make sure the text element takes up the whole available space
                              SizedBox(
                                  width: double.infinity,
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 4,
                                          left: 10,
                                          right: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: GestureDetector(
                                                  onLongPress: () {
                                                    Clipboard.setData(
                                                        ClipboardData(
                                                            text: videoMetadata
                                                                .title));
                                                    // TODO: Add vibration feedback for mobile
                                                    ToastMessageShower.showToast(
                                                        "Copied video title to clipboard",
                                                        context);
                                                  },
                                                  child: Text(
                                                      videoMetadata.title,
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines:
                                                          descriptionExpanded
                                                              ? 10
                                                              : 2))),
                                          IconButton(
                                              icon: Icon(
                                                descriptionExpanded
                                                    ? Icons.keyboard_arrow_up
                                                    : Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 30.0,
                                              ),
                                              onPressed: () => setState(() {
                                                    descriptionExpanded =
                                                        !descriptionExpanded;
                                                  }))
                                        ],
                                      ))),
                              if (descriptionExpanded) ...[
                                Padding(
                                    padding: const EdgeInsets.only(
                                        left: 10, right: 10, bottom: 8),
                                    child: Text(videoMetadata.description ??
                                        "No description available")),
                              ],
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 10, right: 10),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          Text(
                                              videoMetadata.viewsTotal == null
                                                  ? "-"
                                                  : "${convertViewsIntoHumanReadable(videoMetadata.viewsTotal!)} ",
                                              maxLines: 1,
                                              style: mediumTextStyle),
                                          Skeleton.shade(
                                              child: Icon(
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  Icons.remove_red_eye))
                                        ]),
                                        Row(children: [
                                          Skeleton.shade(
                                              child: Icon(
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  Icons.thumb_up)),
                                          const SizedBox(width: 5),
                                          Text(
                                              "${videoMetadata.ratingsPositiveTotal ?? "-"} "
                                              "| ${videoMetadata.ratingsNegativeTotal ?? "-"}",
                                              maxLines: 1,
                                              style: mediumTextStyle),
                                          const SizedBox(width: 5),
                                          Skeleton.shade(
                                              child: Icon(
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  Icons.thumb_down))
                                        ])
                                      ]))
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
