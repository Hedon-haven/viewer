import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_widget.dart';
import 'progress_widget.dart';
import 'quality_widget.dart';
import 'skip_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController controller =
      VideoPlayerController.networkUrl(Uri.parse(""));
  Timer? hideControlsTimer;
  bool showControls = false;
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

    // use fpv for better video playback
    // TODO: Use platform specific codecs
    registerWith(options: {
      "platforms": ["linux"],
    });

    widget.videoMetadata.whenComplete(() async {
      isLoadingMetadata = false;
      videoMetadata = await widget.videoMetadata;
      initVideoPlayer();
      setState(() {});
    });
  }

  void initVideoPlayer() {
    // read preferred video quality setting
    int preferredQuality = sharedStorage.getInt("preferred_video_quality")!;
    selectedResolution = preferredQuality;

    if (videoMetadata.m3u8Uris.length > 1) {
      // select the preferred quality, or the closest to it

      // Sort the available resolutions in ascending order
      sortedResolutions = videoMetadata.m3u8Uris.keys.toList()..sort();

      // If the user's choice is not in the list, find the next highest resolution
      if (!sortedResolutions!.contains(preferredQuality)) {
        int nextHighest = preferredQuality;
        for (int i = 0; i < sortedResolutions!.length - 1; i++) {
          if (sortedResolutions![i] < preferredQuality) {
            nextHighest = sortedResolutions![i + 1];
          }
        }
        selectedResolution = nextHighest;
      }
    } else {
      selectedResolution = sortedResolutions![0];
    }
    // Check if m3u8 links exist and display toast message
    if (videoMetadata.m3u8Uris[selectedResolution] == null) {
      // TODO: Add VR check
      //if (.virtualReality) {
      //  videoMetadata.provider
      //      ?.displayError("Virtual reality videos not yet supported");
      //}
      videoMetadata.provider
          ?.displayError("Coudlnt play video: M3U8 url not found");
      // go back a screen
      Navigator.pop(context);
    }
    initVideoController(videoMetadata.m3u8Uris[selectedResolution]!);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  void initVideoController(Uri url) {
    final bool isPlaying = controller.value.isPlaying;
    final oldPosition = controller.value.position;

    print("Setting new url: $url");
    controller = VideoPlayerController.networkUrl(url);
    controller.addListener(() {
      // this is later used to check if the video is buffering
      setState(() {});
    });
    controller.initialize().then((value) {
      controller.seekTo(oldPosition);
      if (firstPlay) {
        firstPlay = false;
        if (sharedStorage.getBool("start_in_fullscreen")!) {
          print("Full-screening video as per settings");
          toggleFullScreen();
        }
        if (sharedStorage.getBool("auto_play")!) {
          print("Autostarting video as per settings");
          controller.play();
          hideControlsOverlay();
          return; // return, so that controls arent automatically shown
        }
        // only show controls after controller is fully done initializing
        showControls = true;
      }
      if (isPlaying) {
        controller.play();
      }
    });
  }

  void hideControlsOverlay() {
    hideControlsTimer?.cancel(); // stop any old timers
    hideControlsTimer = Timer(const Duration(seconds: 3), () {
      print("Timer is completed");
      setState(() {
        showControls = false;
      });
    });
  }

  void showControlsOverlay() {
    print("Show controls triggered");
    if (firstPlay) {
      // refuse to show controls while video is initializing the first time
      return;
    }
    // Check if hideControlsTimer is empty, so that the isActive check doesnt throw a null error
    if (hideControlsTimer != null && controller.value.isPlaying) {
      if (!hideControlsTimer!.isActive) {
        print("Timer not running, starting it");
        hideControlsOverlay();
      }
    } else {
      print("Timer is running, stopping it");
      hideControlsTimer?.cancel();
    }
    setState(() {
      showControls = !showControls;
      print("showControls set to: $showControls");
    });
  }

  void playPausePlayer() {
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        WakelockPlus.disable();
        hideControlsTimer?.cancel();
      } else {
        controller.play();
        WakelockPlus.enable();
        hideControlsOverlay();
      }
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
                    controller.pause();
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
                        child: GestureDetector(
                          // pass taps to elements below
                          behavior: HitTestBehavior.translucent,
                          onTap: showControlsOverlay,
                          // toggle fullscreen when user swipes down or up on video
                          // down only works in fullscreen
                          // up only works in non-fullscreen
                          // TODO: Add nice animation ala youtube app
                          onVerticalDragEnd: (details) {
                            if (details.velocity.pixelsPerSecond.dy *
                                    (isFullScreen ? 1 : -1) >
                                0) {
                              toggleFullScreen();
                            }
                          },
                          child: Container(
                              // add a background to be able to switch to pitch-black when in fullscreen
                              color: isFullScreen
                                  ? Colors.black
                                  : Colors.transparent,
                              child: Container(
                                height: MediaQuery.of(context).orientation ==
                                        Orientation.landscape
                                    ? MediaQuery.of(context).size.height
                                    : MediaQuery.of(context).size.width *
                                        9 /
                                        16,
                                color: isLoadingMetadata
                                    ? Colors.green
                                    : Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    // the video widget itself
                                    controller.value.isInitialized ||
                                            isLoadingMetadata
                                        ? AspectRatio(
                                            aspectRatio: 16 / 9,
                                            child: Skeleton.replace(
                                                child: isLoadingMetadata
                                                    ? const Placeholder()
                                                    : VideoPlayer(controller)),
                                          )
                                        : const CircularProgressIndicator(
                                            color: Colors.white),
                                    // gray background to make buttons more visible when overlay is on
                                    OverlayWidget(
                                      showControls: showControls,
                                      child: Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ),
                                    SkipWidget(
                                        showControls: showControls,
                                        controller: controller,
                                        skipBy: sharedStorage
                                            .getInt("seek_duration")!),
                                    OverlayWidget(
                                      showControls: showControls,
                                      child: controller.value.isBuffering
                                          ? const CircularProgressIndicator(
                                              color: Colors.white,
                                            )
                                          : CircleAvatar(
                                              radius: 28,
                                              backgroundColor:
                                                  Colors.black.withOpacity(0.2),
                                              child: IconButton(
                                                splashColor: Colors.transparent,
                                                icon: Icon(
                                                  controller.value.isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  size: 40.0,
                                                  color: Colors.white,
                                                ),
                                                color: Colors.white,
                                                onPressed: playPausePlayer,
                                              ),
                                            ),
                                    ),
                                    // TODO: Show back button while skeletonizer is running
                                    Positioned(
                                        top: 5,
                                        left: 5,
                                        child: OverlayWidget(
                                            showControls: showControls,
                                            child: IconButton(
                                                color: Colors.white,
                                                icon: const Icon(
                                                    Icons.arrow_back),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                }))),
                                    Positioned(
                                        top: 5,
                                        right: 10,
                                        child: QualityWidget(
                                          showControls: showControls,
                                          selectedResolution:
                                              selectedResolution,
                                          onSelected: (newResolution) {
                                            selectedResolution = newResolution;
                                            initVideoController(videoMetadata
                                                .m3u8Uris[selectedResolution]!);
                                          },
                                          sortedResolutions: sortedResolutions,
                                        )),
                                    Positioned(
                                      bottom: 5.0,
                                      left: 20.0,
                                      right: 0.0,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: <Widget>[
                                            Expanded(
                                              child: ProgressBarWidget(
                                                showControls: showControls,
                                                controller: controller,
                                              ),
                                            ),
                                            OverlayWidget(
                                                showControls: showControls,
                                                child: IconButton(
                                                  icon: Icon(
                                                    isFullScreen
                                                        ? Icons.fullscreen_exit
                                                        : Icons.fullscreen,
                                                    color: Colors.white,
                                                    size: 30.0,
                                                  ),
                                                  onPressed: toggleFullScreen,
                                                )),
                                          ]),
                                    ),
                                  ],
                                ),
                              )),
                        ),
                      ),
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
