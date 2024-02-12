import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';
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

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(Uri.parse(
        'https://video3.xhcdn.com/key=zqn3ghY5FmGrSdUVSEOyLQ,end=1707714000/data=188.195.202.101-dvp/media=hls4/multi=256x144:144p,426x240:240p,854x480:480p,1280x720:720p,1920x1080:1080p,3840x2160:2160p/024/242/372/_TPL_.h264.mp4.m3u8'));
    controller.addListener(() {
      setState(() {});
    });
    controller.initialize().then((value) {
      setState(() {});
    });
  }

  void hideControlsOverlay() {
    hideControlsTimer?.cancel(); // stop any old timers
    hideControlsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      print("Ive waited bitch");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent, // pass taps to elements below
        onTap: showControlsOverlay,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // set a fixed height to avoid BoxConstraints errors
              Container(
                  height: MediaQuery.of(context).size.width * 9 / 16,
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
                            child: IconButton(
                              icon: Icon(
                                  controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 50.0,
                                  color: Colors.white),
                              onPressed: playPausePlayer,
                            ),
                          )),
                      Positioned(
                          bottom: 20.0, // adjust this value as needed
                          left: 0.0,
                          right: 0.0,
                          child: IgnorePointer(
                              ignoring: !showControls,
                              child: AnimatedOpacity(
                                  opacity: showControls ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 220),
                                  child: VideoProgressIndicator(controller,
                                      allowScrubbing: true,
                                      colors: const VideoProgressColors(
                                        backgroundColor: Colors.white10,
                                        playedColor: Colors.red,
                                        bufferedColor: Colors.grey,
                                      ))))),
                    ],
                  ))
            ]),
      ),
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(children: [
//         AspectRatio(
//           aspectRatio: controller.value.aspectRatio,
//           child: VideoPlayer(controller),
//         ),
//         Text("Total Duration: ${controller.value.duration}"),
//         VideoProgressIndicator(controller,
//             allowScrubbing: true,
//             colors: const VideoProgressColors(
//               backgroundColor: Colors.redAccent,
//               playedColor: Colors.green,
//               bufferedColor: Colors.purple,
//             )),
//         Row(
//           children: [
//             IconButton(
//                 onPressed: () {
//                   if (controller.value.isPlaying) {
//                     controller.pause();
//                   } else {
//                     controller.play();
//                   }
//
//                   setState(() {});
//                 },
//                 icon: Icon(controller.value.isPlaying
//                     ? Icons.pause
//                     : Icons.play_arrow)),
//             IconButton(
//                 onPressed: () {
//                   controller.seekTo(const Duration(seconds: 0));
//
//                   setState(() {});
//                 },
//                 icon: const Icon(Icons.stop))
//           ],
//         )
//       ]),
//     );
//   }
