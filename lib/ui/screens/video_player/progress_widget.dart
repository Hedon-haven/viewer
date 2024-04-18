import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'overlay_widget.dart';

class ProgressBarWidget extends StatelessWidget {
  bool showControls;
  final Player player;

  ProgressBarWidget(
      {super.key, required this.showControls, required this.player});

  @override
  Widget build(BuildContext context) {
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
        progress: player.state.position,
        buffered: player.state.buffer,
        total: player.state.duration,
        onSeek: (duration) async {
          print("Current position: ${player.state.position}");
          print("Seeking to: $duration");
          // To avoid visual glitch, force set the position to new duration
          await player.seek(duration);
          print("New position: ${player.state.position}");
        },
      ),
    );
  }
}
