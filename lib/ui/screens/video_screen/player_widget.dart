import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/debug_screen.dart';

class VideoPlayerWidget extends StatefulWidget {
  UniversalVideoMetadata videoMetadata;
  bool isFullScreen;
  final Function() toggleFullScreen;

  VideoPlayerWidget(
      {super.key,
      required this.videoMetadata,
      required this.isFullScreen,
      required this.toggleFullScreen});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  int skipBy = sharedStorage.getInt("seek_duration")!;
  Timer? hideControlsTimer;
  bool showControls = false;
  bool firstPlay = true;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];
  VideoPlayerController controller =
      VideoPlayerController.networkUrl(Uri.parse(""));

  @override
  void initState() {
    super.initState();

    // use fpv for better video playback
    // TODO: Use platform specific codecs
    registerWith(options: {
      "platforms": ["linux"],
    });

    initVideoPlayer();
  }

  void initVideoPlayer() {
    // read preferred video quality setting
    int preferredQuality = sharedStorage.getInt("preferred_video_quality")!;
    selectedResolution = preferredQuality;

    if (widget.videoMetadata.virtualReality) {
      widget.videoMetadata.plugin
          ?.displayError("Virtual reality videos not yet supported");
      Navigator.pop(context);
    }

    if (widget.videoMetadata.m3u8Uris.length > 1) {
      // select the preferred quality, or the closest to it

      // Sort the available resolutions in ascending order
      sortedResolutions = widget.videoMetadata.m3u8Uris.keys.toList()..sort();

      // If the user's choice is not in the list, find the next highest resolution
      if (!sortedResolutions.contains(preferredQuality)) {
        int nextHighest = preferredQuality;
        for (int i = 0; i < sortedResolutions.length - 1; i++) {
          if (sortedResolutions[i] < preferredQuality) {
            nextHighest = sortedResolutions[i + 1];
          }
        }
        selectedResolution = nextHighest;
      }
    } else {
      selectedResolution = sortedResolutions[0];
    }
    // Check if m3u8 links exist and display toast message
    if (widget.videoMetadata.m3u8Uris[selectedResolution] == null) {
      widget.videoMetadata.plugin
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
    hideControlsTimer?.cancel();
  }

  void initVideoController(Uri url) {
    final bool isPlaying = controller.value.isPlaying;
    final oldPosition = controller.value.position;

    logger.i("Setting new url: $url");
    controller = VideoPlayerController.networkUrl(url);
    controller.addListener(() {
      // rebuild tree when video state changes
      setState(() {});
    });
    controller.initialize().then((value) {
      controller.seekTo(oldPosition);
      if (firstPlay) {
        firstPlay = false;
        if (sharedStorage.getBool("start_in_fullscreen")!) {
          logger.i("Full-screening video as per settings");
          widget.toggleFullScreen.call();
        }
        if (sharedStorage.getBool("auto_play")!) {
          logger.i("Autostarting video as per settings");
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
      logger.d("Timer is completed");
      setState(() {
        showControls = false;
      });
    });
  }

  void showControlsOverlay() {
    logger.d("Show controls triggered");
    if (firstPlay) {
      // refuse to show controls while video is initializing the first time
      return;
    }
    // Check if hideControlsTimer is empty, so that the isActive check doesnt throw a null error
    if (hideControlsTimer != null && controller.value.isPlaying) {
      if (!hideControlsTimer!.isActive) {
        logger.d("Timer not running, starting it");
        hideControlsOverlay();
      }
    } else {
      logger.d("Timer is running, stopping it");
      hideControlsTimer?.cancel();
    }
    setState(() {
      showControls = !showControls;
      logger.d("showControls set to: $showControls");
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text("Create bug report"),
                    onTap: () {
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BugReportScreen(
                                      debugObject:
                                          widget.videoMetadata.convertToMap())))
                          .then((value) => Navigator.of(context).pop());
                    },
                  )
                ],
              );
            },
          );
        },
        // pass taps to elements below
        behavior: HitTestBehavior.translucent,
        onTap: showControlsOverlay,
        // toggle fullscreen when user swipes down or up on video
        // down only works in fullscreen
        // up only works in non-fullscreen
        // TODO: Add nice animation ala youtube app
        onVerticalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dy *
                  (widget.isFullScreen ? 1 : -1) >
              0) {
            widget.toggleFullScreen.call();
          }
        },
        child: Container(
            // add a background to be able to switch to pitch-black when in fullscreen
            color: widget.isFullScreen ? Colors.black : Colors.transparent,
            child: SizedBox(
              height:
                  MediaQuery.of(context).orientation == Orientation.landscape
                      ? MediaQuery.of(context).size.height
                      : MediaQuery.of(context).size.width * 9 / 16,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // the video widget itself
                  controller.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: controller.value.isInitialized
                              ? controller.value.aspectRatio
                              : 16 / 9,
                          // This makes the video 16:9 while loading -> skeleton looks weird otherwise
                          child: VideoPlayer(controller),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                  // gray background to make buttons more visible when overlay is on
                  OverlayWidget(
                    showControls: showControls,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  buildSkipWidget(),
                  OverlayWidget(
                    showControls: showControls,
                    child: controller.value.isBuffering
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.black.withOpacity(0.2),
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
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                Navigator.pop(context);
                              }))),
                  Positioned(top: 5, right: 10, child: buildQualityDropdown()),
                  Positioned(
                    bottom: 5.0,
                    left: 20.0,
                    right: 0.0,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: buildProgressBar(),
                          ),
                          OverlayWidget(
                              showControls: showControls,
                              child: IconButton(
                                icon: Icon(
                                  widget.isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                  size: 30.0,
                                ),
                                onPressed: widget.toggleFullScreen.call,
                              )),
                        ]),
                  ),
                ],
              ),
            )));
  }

  Widget buildQualityDropdown() {
    return OverlayWidget(
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
            selectedResolution =
                int.parse(newValue!.substring(0, newValue.length - 1));
            initVideoController(
                widget.videoMetadata.m3u8Uris[selectedResolution]!);
          },
          items: sortedResolutions.map<DropdownMenuItem<String>>((int value) {
            return DropdownMenuItem<String>(
              value: "${value}p",
              child: Text("${value}p",
                  style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        ));
  }

  Widget buildProgressBar() {
    return OverlayWidget(
      showControls: showControls,
      child: ProgressBar(
        // TODO: Possibly make TimeLabels in Youtube style
        timeLabelLocation: TimeLabelLocation.sides,
        timeLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        thumbGlowRadius: 0.0,
        // TODO: Find a way to increase the hitbox without increasing the thumb radius
        thumbRadius: 6.0,
        barCapShape: BarCapShape.square,
        barHeight: 2.0,
        // set baseBarColor to white, with low opacity
        baseBarColor: Colors.white.withOpacity(0.2),
        progressBarColor: const Color(0xFFFF0000),
        bufferedBarColor: Colors.grey.withOpacity(0.5),
        thumbColor: const Color(0xFFFF0000),
        progress: controller.value.position,
        buffered: controller.value.buffered.firstOrNull?.end,
        total: controller.value.duration,
        onSeek: (duration) => controller.seekTo(duration),
      ),
    );
  }

  Widget buildSkipWidget() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Padding(
          padding: const EdgeInsets.only(right: 100),
          child: OverlayWidget(
              showControls: showControls,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Colors.black.withOpacity(0.2),
                child: IconButton(
                  splashColor: Colors.transparent,
                  icon: const Icon(
                    Icons.fast_rewind,
                    size: 30.0,
                    color: Colors.white,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    final currentTime = controller.value.position;
                    Duration newTime = const Duration(seconds: 0);
                    // Skipping by a negative value leads to unexpected results
                    logger.d(currentTime.inSeconds);
                    logger.d("Skipping by: $skipBy");
                    if (currentTime.inSeconds > skipBy) {
                      // multiply by -1 to skip backwards
                      newTime = currentTime + Duration(seconds: skipBy * -1);
                    }
                    logger.d("Seeking to: $newTime");
                    controller.seekTo(newTime);
                  },
                ),
              ))),
      Padding(
          padding: const EdgeInsets.only(left: 100),
          child: OverlayWidget(
              showControls: showControls,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Colors.black.withOpacity(0.2),
                child: IconButton(
                  splashColor: Colors.transparent,
                  icon: const Icon(
                    Icons.fast_forward,
                    size: 30.0,
                    color: Colors.white,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    final newTime =
                        controller.value.position + Duration(seconds: skipBy);
                    controller.seekTo(newTime);
                  },
                ),
              )))
    ]);
  }
}

class OverlayWidget extends StatelessWidget {
  final Widget child;
  bool showControls;

  OverlayWidget({
    super.key,
    required this.child,
    required this.showControls,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // TODO: Wait for animation to finish before ignoring touch input
      ignoring: !showControls,
      child: AnimatedOpacity(
        opacity: showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: child,
      ),
    );
  }
}
