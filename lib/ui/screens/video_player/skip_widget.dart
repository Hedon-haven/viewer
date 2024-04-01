import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'overlay_widget.dart';

class SkipWidget extends StatelessWidget {
  bool showControls;
  final int skipBy;
  final VideoPlayerController controller;

  SkipWidget(
      {super.key,
      required this.showControls,
      required this.skipBy,
      required this.controller});

  @override
  Widget build(BuildContext context) {
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
                    print(currentTime.inSeconds);
                    print(skipBy);
                    if (currentTime.inSeconds > skipBy) {
                      // multiply by -1 to skip backwards
                      newTime = currentTime + Duration(seconds: skipBy * -1);
                    }
                    print("Seeking to: $newTime");
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
