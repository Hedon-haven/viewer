import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'overlay_widget.dart';

class ProgressBarWidget extends StatelessWidget {
  bool showControls;
  final VideoPlayerController controller;

  ProgressBarWidget(
      {super.key,
      required this.showControls,
      required this.controller});

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
        progress: controller.value.position,
        buffered: controller.value.buffered.firstOrNull?.end,
        total: controller.value.duration,
        onSeek: (duration) => controller.seekTo(duration),
      ),
    );
  }
}
