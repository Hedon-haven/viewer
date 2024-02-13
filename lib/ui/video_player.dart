import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController controller;
  Timer? hideControlsTimer;
  bool showControls = true;
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();

    // stock video_player doesnt support all platforms (linux)
    // use fpv package to provide support
    registerWith(options: {
      'platforms': ['android', 'linux']
    });
    controller = VideoPlayerController.networkUrl(Uri.parse(
        'https://video3.xhcdn.com/key=zqn3ghY5FmGrSdUVSEOyLQ,end=1707714000/data=188.195.202.101-dvp/media=hls4/multi=256x144:144p,426x240:240p,854x480:480p,1280x720:720p,1920x1080:1080p,3840x2160:2160p/024/242/372/_TPL_.h264.mp4.m3u8'));
    controller.addListener(() {
      setState(() {});
    });
    controller.initialize().then((value) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
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
    // if timer isnt running, start it
    if (!hideControlsTimer!.isActive) {
      print("Timer not running, starting it");
      hideControlsOverlay();
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
        hideControlsTimer?.cancel();
      } else {
        controller.play();
        hideControlsOverlay();
      }
    });
  }

  void toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
      if (isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        AutoOrientation.landscapeAutoMode(forceSensor: true);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        AutoOrientation.portraitAutoMode();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isFullScreen
          ? RotatedBox(
              quarterTurns: 4,
              child: buildVideoPlayer(context),
            )
          : buildVideoPlayer(context),
    );
  }

  Widget buildVideoPlayer(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // pass taps to elements below
      onTap: showControlsOverlay,
      // toggle fullscreen when user swipes down or up on video
      // down only works in fullscreen
      // up only works in non-fullscreen
      // TODO: Add nice animation ala youtube app
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy * (isFullScreen ? 1 : -1) > 0) {
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
              Container(
                height: isFullScreen
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
                    AnimatedOpacity(
                      opacity: showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !showControls,
                      child: AnimatedOpacity(
                        opacity: showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black.withOpacity(0.1),
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
                    ),
                    Positioned(
                      bottom: 5.0,
                      left: 20.0,
                      right: 0.0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                                child: IgnorePointer(
                              ignoring: !showControls,
                              child: AnimatedOpacity(
                                opacity: showControls ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 220),
                                child: ProgressBar(
                                  // TODO: Possibly make TimeLabels in Youtube style
                                  timeLabelLocation: TimeLabelLocation.sides,
                                  thumbGlowRadius: 0.0,
                                  thumbRadius: 6.0,
                                  barCapShape: BarCapShape.square,
                                  barHeight: 2.0,
                                  // set baseBarColor to white, with low opacity
                                  baseBarColor: Colors.white.withOpacity(0.2),
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
                            )),
                            IgnorePointer(
                                ignoring: !showControls,
                                child: AnimatedOpacity(
                                    opacity: showControls ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 220),
                                    child: IconButton(
                                      icon: Icon(
                                        isFullScreen
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        color: Colors.white,
                                        size: 30.0,
                                      ),
                                      onPressed: toggleFullScreen,
                                    )))
                          ]),
                    ),
                  ],
                ),
              ),
            ],
          )),
    );
  }
}
