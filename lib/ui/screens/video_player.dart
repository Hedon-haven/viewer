import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/overlay_widget.dart';
import 'package:url_launcher/url_launcher.dart';
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
    int preferredQuality = localStorage.getInt("preferred_video_quality")!;
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
        if (!isPlaying) {
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
    return Scaffold(
        body: Column(children: <Widget>[
      SizedBox(
          height: MediaQuery.of(context).orientation == Orientation.landscape
              ? MediaQuery.of(context).size.height
              : MediaQuery.of(context).size.width * 9 / 16,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            // pass taps to elements below
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    // set a fixed height to avoid BoxConstraints errors
                    SizedBox(
                      height: MediaQuery.of(context).orientation ==
                              Orientation.landscape
                          ? MediaQuery.of(context).size.height
                          : MediaQuery.of(context).size.width * 9 / 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          controller.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: VideoPlayer(controller),
                                )
                              : const CircularProgressIndicator(),
                          OverlayWidget(
                            showControls: showControls,
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                          OverlayWidget(
                            showControls: showControls,
                            child: controller.value.isBuffering
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        Colors.black.withOpacity(0.1),
                                    child: IconButton(
                                      splashColor: Colors.transparent,
                                      icon: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: 40.0,
                                        color: Colors.white,
                                      ),
                                      onPressed: playPausePlayer,
                                    ),
                                  ),
                          ),
                          Positioned(
                              top: 10.0,
                              left: 20.0,
                              child: OverlayWidget(
                                  showControls: showControls,
                                  // TODO: Force animation to always go downwards
                                  child: DropdownButton<int>(
                                    // dropdownColor: Colors.black,
                                    padding: const EdgeInsets.all(0.0),
                                    value: selectedResolution,
                                    underline: const SizedBox(),
                                    onChanged: (int? newValue) async {
                                      selectedResolution = newValue;
                                      initVideoController(widget.videoMetadata
                                          .m3u8Uris[selectedResolution]!);
                                      setState(() {});
                                    },
                                    items: sortedResolutions!
                                        .map<DropdownMenuItem<int>>(
                                            (int value) {
                                      return DropdownMenuItem<int>(
                                        value: value,
                                        child: Text(value.toString()),
                                      );
                                    }).toList(),
                                  ))),
                          Positioned(
                              top: 6,
                              right: 5,
                              child: OverlayWidget(
                                  showControls: showControls,
                                  child: IconButton(
                                    icon: const Icon(Icons.open_in_browser),
                                    onPressed: () async {
                                      await launchUrl(Uri.parse(widget
                                              .videoMetadata
                                              .pluginOrigin!
                                              .videoEndpoint +
                                          widget.videoMetadata.videoID));
                                    },
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
                                        thumbGlowRadius: 0.0,
                                        thumbRadius: 6.0,
                                        barCapShape: BarCapShape.square,
                                        barHeight: 2.0,
                                        // set baseBarColor to white, with low opacity
                                        baseBarColor:
                                            Colors.white.withOpacity(0.2),
                                        progressBarColor:
                                            const Color(0xFFFF0000),
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
                  ],
                )),
          )),
      // only show the following widgets if not in fullscreen
      if (!isFullScreen) ...[
        Column(children: <Widget>[
          // make sure the text element takes up the whole available space
          SizedBox(
              width: double.infinity,
              child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 10, right: 10),
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
