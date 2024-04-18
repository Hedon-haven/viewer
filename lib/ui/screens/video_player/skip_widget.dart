import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'overlay_widget.dart';

class SkipWidget extends StatelessWidget {
  bool showControls;
  final int skipBy;
  final Player player;

  SkipWidget(
      {super.key,
      required this.showControls,
      required this.skipBy,
      required this.player});

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
                    final currentTime = player.state.position;
                    Duration newTime = const Duration(seconds: 0);
                    // Skipping by a negative value leads to unexpected results
                    print("Current time ${currentTime.inSeconds}");
                    print("Skipping by $skipBy");
                    if (currentTime.inSeconds > skipBy) {
                      // multiply by -1 to skip backwards
                      newTime = currentTime + Duration(seconds: skipBy * -1);
                    }
                    print("Seeking to: $newTime");
                    player.seek(newTime);
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
                        player.state.position + Duration(seconds: skipBy);
                    print("Seeking to: $newTime");
                    player.seek(newTime);
                  },
                ),
              )))
    ]);
  }
}
