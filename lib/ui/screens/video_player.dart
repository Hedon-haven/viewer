import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/overlay_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

class VideoPlayerScreen extends StatelessWidget {
  final UniversalVideoMetadata videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: _VideoPlayerWidget(
        videoMetadata: videoMetadata,
      )),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final UniversalVideoMetadata videoMetadata;

  const _VideoPlayerWidget({required this.videoMetadata});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController controller =
      VideoPlayerController.networkUrl(Uri.parse(""));
  Timer? hideControlsTimer;
  bool showControls = false;
  bool isFullScreen = false;
  bool firstPlay = true;
  int? selectedResolution;
  List<int>? sortedResolutions;

  @override
  void initState() {
    super.initState();

    // stock video_player doesnt support all platforms (linux)
    // use fpv package to provide support
    registerWith(options: {
      'platforms': ['linux']
    });

    // read preferred video quality setting
    int preferredQuality = sharedStorage.getInt("preferred_video_quality")!;
    selectedResolution = preferredQuality;

    if (widget.videoMetadata.m3u8Uris.length > 1) {
      // select the preferred quality, or the closest to it

      // Sort the available resolutions in ascending order
      sortedResolutions = widget.videoMetadata.m3u8Uris.keys.toList()..sort();

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
    }
    // Check if m3u8 links exist and display toast message
    if (widget.videoMetadata.m3u8Uris[selectedResolution] == null) {
      // TODO: Add VR check
      //if (widget.videoMetadata.virtualReality) {
      //  widget.videoMetadata.pluginOrigin
      //      ?.displayError("Virtual reality videos not yet supported");
      //}
      widget.videoMetadata.pluginOrigin
          ?.displayError("Coudlnt play video: M3U8 url not found");
      // go back a screen
      Navigator.pop(context);
    }
    initVideoController(widget.videoMetadata.m3u8Uris[selectedResolution]!);
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
      setState(() {});
    });
    controller.initialize().then((value) {
      setState(() {
        controller.seekTo(oldPosition);
        if (firstPlay) {
          firstPlay = false;
          if (sharedStorage.getBool("start_in_fullscreen")!) {
            toggleFullScreen();
          }
          if (sharedStorage.getBool("auto_play")!) {
            controller.play();
          }
          controller.play();
        } else if (!isPlaying) {
          showControls = true;
        } else {
          controller.play();
        }
      });
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
    setState(() {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
        child: Column(children: <Widget>[
          SizedBox(
              height:
                  MediaQuery.of(context).orientation == Orientation.landscape
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
                  color: isFullScreen ? Colors.black : Colors.transparent,
                  child: SizedBox(
                    height: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? MediaQuery.of(context).size.height
                        : MediaQuery.of(context).size.width * 9 / 16,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // the video widget itself
                        controller.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: 16 / 9,
                                child: VideoPlayer(controller),
                              )
                            : const CircularProgressIndicator(),
                        // gray background to make buttons more visible when overlay is on
                        OverlayWidget(
                          showControls: showControls,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                        // Add double tap skip support
                        // TODO: Fix animation not working with single tap
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(right: 100),
                                  child: OverlayWidget(
                                      showControls: showControls,
                                      child: CircleAvatar(
                                        radius: 23,
                                        backgroundColor:
                                            Colors.black.withOpacity(0.2),
                                        child: IconButton(
                                          splashColor: Colors.transparent,
                                          icon: const Icon(
                                            Icons.fast_rewind,
                                            size: 30.0,
                                            color: Colors.white,
                                          ),
                                          color: Colors.white,
                                          onPressed: () {
                                            if (controller
                                                .value.isInitialized) {
                                              final currentTime =
                                                  controller.value.position;
                                              // multiply by -1 to skip backwards
                                              final newTime = currentTime +
                                                  Duration(
                                                      seconds: sharedStorage.getInt(
                                                              "seek_duration")! *
                                                          -1);
                                              controller.seekTo(newTime);
                                            }
                                          },
                                        ),
                                      ))),
                              Padding(
                                  padding: const EdgeInsets.only(left: 100),
                                  child: OverlayWidget(
                                      showControls: showControls,
                                      child: CircleAvatar(
                                        radius: 23,
                                        backgroundColor:
                                            Colors.black.withOpacity(0.2),
                                        child: IconButton(
                                          splashColor: Colors.transparent,
                                          icon: const Icon(
                                            Icons.fast_forward,
                                            size: 30.0,
                                            color: Colors.white,
                                          ),
                                          color: Colors.white,
                                          onPressed: () {
                                            if (controller
                                                .value.isInitialized) {
                                              final currentTime =
                                                  controller.value.position;
                                              final newTime = currentTime +
                                                  Duration(
                                                      seconds:
                                                          sharedStorage.getInt(
                                                              "seek_duration")!);
                                              controller.seekTo(newTime);
                                            }
                                          },
                                        ),
                                      )))
                            ]),
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
                        Positioned(
                            top: 5,
                            left: 5,
                            child: OverlayWidget(
                                showControls: showControls,
                                // TODO: Force animation to always go downwards
                                child: IconButton(
                                    color: Colors.white,
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    }))),
                        Positioned(
                            top: 5,
                            right: 10,
                            child: OverlayWidget(
                                showControls: showControls,
                                // TODO: Force animation to always go downwards
                                child: DropdownButton<String>(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  dropdownColor: Colors.black87,
                                  padding: const EdgeInsets.all(0.0),
                                  value: "${selectedResolution}p",
                                  underline: const SizedBox(),
                                  onChanged: (String? newValue) async {
                                    selectedResolution = int.parse(newValue!
                                        .substring(0, newValue.length - 1));
                                    initVideoController(widget.videoMetadata
                                        .m3u8Uris[selectedResolution]!);
                                    setState(() {});
                                  },
                                  items: sortedResolutions!
                                      .map<DropdownMenuItem<String>>((int value) {
                                    return DropdownMenuItem<String>(
                                      value: "${value}p",
                                      child: Text("${value}p",
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    );
                                  }).toList(),
                                ))),
                        Positioned(
                          bottom: 5.0,
                          left: 20.0,
                          right: 0.0,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: OverlayWidget(
                                    showControls: showControls,
                                    child: ProgressBar(
                                      // TODO: Possibly make TimeLabels in Youtube style
                                      timeLabelLocation:
                                          TimeLabelLocation.sides,
                                      timeLabelTextStyle: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                      thumbGlowRadius: 0.0,
                                      // TODO: Find a way to increase the hitbox without increasing the thumb radius
                                      thumbRadius: 6.0,
                                      barCapShape: BarCapShape.square,
                                      barHeight: 2.0,
                                      // set baseBarColor to white, with low opacity
                                      baseBarColor:
                                          Colors.white.withOpacity(0.2),
                                      progressBarColor: const Color(0xFFFF0000),
                                      bufferedBarColor:
                                          Colors.grey.withOpacity(0.5),
                                      thumbColor: const Color(0xFFFF0000),
                                      progress: controller.value.position,
                                      buffered: controller
                                          .value.buffered.firstOrNull?.end,
                                      total: controller.value.duration,
                                      onSeek: (duration) =>
                                          controller.seekTo(duration),
                                    ),
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
                  ),
                ),
              )),
          // only show the following widgets if not in fullscreen
          if (!isFullScreen) ...[
            Column(children: <Widget>[
              // make sure the text element takes up the whole available space
              SizedBox(
                  width: double.infinity,
                  child: Padding(
                      padding:
                          const EdgeInsets.only(top: 8, left: 10, right: 10),
                      child: Text(widget.videoMetadata.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2))),
            ])
          ]
        ]));
  }
}

// Browser button:
// OverlayWidget(
//                                   showControls: showControls,
//                                   child: IconButton(
//                                     color: Colors.white,
//                                     icon: const Icon(Icons.open_in_browser),
//                                     onPressed: () async {
//                                       await launchUrl(Uri.parse(widget
//                                               .videoMetadata
//                                               .pluginOrigin!
//                                               .videoEndpoint +
//                                           widget.videoMetadata.videoID));
//                                     },
//                                   ))
