import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '/ui/screens/bug_report.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

class VideoPlayerWidget extends StatefulWidget {
  UniversalVideoMetadata videoMetadata;
  List<Uint8List>? progressThumbnails;
  bool isFullScreen;
  final Function(String reason) updateFailedToLoadReason;
  final Function() toggleFullScreen;

  VideoPlayerWidget(
      {super.key,
      required this.videoMetadata,
      required this.progressThumbnails,
      required this.isFullScreen,
      required this.toggleFullScreen,
      required this.updateFailedToLoadReason});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  int skipBy = 5;
  Timer? hideControlsTimer;
  bool showControls = false;
  bool hidePlayControls = false;
  bool firstPlay = true;
  Duration? seekTo = Duration.zero;
  bool showProgressThumbnail = false;
  bool enableProgressThumbnails = false;
  bool playerReady = false;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];
  Player player = Player();
  late VideoController controller;
  Uint8List timelineProgressThumbnail = Uint8List(0);
  Uint8List emptyImage = Uint8List(0);
  double progressThumbnailPosition = 0.0;

  @override
  void initState() {
    super.initState();

    controller = VideoController(player);

    sharedStorage.getBool("media_show_progress_thumbnails").then((value) {
      enableProgressThumbnails = value!;
    });

    sharedStorage.getInt("media_seek_duration").then((value) {
      skipBy = value!;
    });

    initVideoPlayer();
  }

  void initVideoPlayer() async {
    // read preferred video quality setting
    int preferredQuality =
        (await sharedStorage.getInt("media_preferred_video_quality"))!;
    selectedResolution = preferredQuality;

    if (widget.videoMetadata.virtualReality) {
      widget
          .updateFailedToLoadReason("Virtual reality videos not yet supported");
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
      widget
          .updateFailedToLoadReason("Couldn't play video: M3U8 url not found");
    }
    initVideoController(widget.videoMetadata.m3u8Uris[selectedResolution]!);
  }

  @override
  void dispose() async {
    await player.dispose();
    hideControlsTimer?.cancel();
    super.dispose();
  }

  void initVideoController(Uri url) {
    final bool isPlaying = player.state.playing;
    final oldPosition = player.state.position;
    logger.d("Old position: $oldPosition");

    player.stream.position.listen((_) {
      // FIXME: MediaKit wont listen to seekTo immediately after player.open()
      if (seekTo != null && Platform.isAndroid) {
        logger.w("Force-seeking to: $seekTo");
        player.seek(seekTo!);
        seekTo = null;
      }

      // rebuild tree when video position changes
      // make sure tree is still mounted
      if (mounted) setState(() {});
    });

    logger.i("Setting new url: $url");
    setState(() => playerReady = false);
    player.open(Media(url.toString())).then((value) async {
      if (firstPlay) {
        logger.i("First play");
        firstPlay = false;
        if ((await sharedStorage.getBool("media_start_in_fullscreen"))!) {
          logger.i("Full-screening video as per settings");
          widget.toggleFullScreen.call();
        }
        if ((await sharedStorage.getBool("media_auto_play"))!) {
          logger.i("Autostarting video as per settings");
          await player.play();
          hideControlsOverlay();
          return; // return, so that controls arent automatically shown
        } else {
          // FIXME: Mediakit has a bug where hls videos autoplay
          await player.pause();
        }
        // only show controls after controller is fully done initializing
        showControls = true;
      }
      if (isPlaying) {
        logger.i("Resuming video");
        await player.play();
      }
      seekTo = oldPosition;
      setState(() => playerReady = true);
    });
  }

  void hideControlsOverlay() {
    hideControlsTimer?.cancel(); // stop any old timers
    hideControlsTimer = Timer(const Duration(seconds: 3), () {
      logger.d("Timer is completed");
      if (showProgressThumbnail) {
        // don't hide controls while progress thumbnail is shown
        logger.d("Progress thumbnail shown, not hiding controls");
        return;
      }
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
    if (hideControlsTimer != null && player.state.playing) {
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
      if (player.state.playing) {
        player.pause();
        WakelockPlus.disable();
        hideControlsTimer?.cancel();
      } else {
        player.play();
        WakelockPlus.enable();
        hideControlsOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        onPopInvoked: (goingToPop) {
          // immediately stop video if popping
          if (goingToPop) {
            logger.d("Stopping video on pop");
            player.pause();
          }
        },
        child: GestureDetector(
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
                                      builder: (context) =>
                                          BugReportScreen(debugObject: [
                                            widget.videoMetadata.convertToMap()
                                          ])))
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
                  height: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? MediaQuery.of(context).size.height
                      : MediaQuery.of(context).size.width * 9 / 16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      playerReady
                          ? AspectRatio(
                              aspectRatio:
                                  player.state.videoParams.aspect != null
                                      ? player.state.videoParams.aspect!
                                      : 16 / 9,
                              // This makes the video 16:9 while loading -> skeleton looks weird otherwise
                              child: Video(
                                  controller: controller,
                                  controls: NoVideoControls),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white),
                      // gray background to make buttons more visible when overlay is on
                      OverlayWidget(
                        showControls: showControls,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                      buildSkipWidget(),
                      OverlayWidget(
                        showControls: showControls && !hidePlayControls,
                        child: player.state.buffering
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.2),
                                child: IconButton(
                                  splashColor: Colors.transparent,
                                  icon: Icon(
                                    player.state.playing
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
                          left: progressThumbnailPosition,
                          bottom: 50,
                          // TODO: Set size limits
                          child: OverlayWidget(
                              showControls: showControls,
                              child: showProgressThumbnail
                                  ? widget.progressThumbnails != null
                                      ? Image.memory(timelineProgressThumbnail,
                                          width: 160, height: 90)
                                      : Container(
                                          color: Colors.black,
                                          width: 160,
                                          height: 90,
                                          child: const Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.white)))
                                  : const SizedBox())),
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
                      Positioned(
                          top: 5, right: 10, child: buildQualityDropdown()),
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
                ))));
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
          // The following drag functions are called after the user starts/stops/drags and the screen is updated
          // Therefore anything that is done in these functions wont have an immediate effect, unless something else also updates
          // Use setState to force an update
          onDragStart: !enableProgressThumbnails
              ? null
              : (_) {
                  // if the list is empty (i.e. the getProgressThumbnails function
                  // failed or the provider has no thumbnails), don't show the loading thumbnail
                  if (widget.progressThumbnails?.isNotEmpty ?? true) {
                    logger.d("Drag start, showing progress thumbnail");
                    setState(() {
                      hidePlayControls = true;
                      showProgressThumbnail = true;
                    });
                  } else {
                    logger.d(
                        "Drag start, not showing progress thumbnail because list is empty");
                  }
                },
          onDragUpdate: !enableProgressThumbnails
              ? null
              : (position) {
                  if (widget.progressThumbnails?.isNotEmpty ?? false) {
                    timelineProgressThumbnail = widget
                        .progressThumbnails![position.timeStamp.inSeconds];
                  }

                  double screenWidth = MediaQuery.of(context).size.width;
                  // make sure the progress image stays within the screen bounds -20px
                  // but still moves with the thumbcursor when it can
                  if (position.globalPosition.dx > 100) {
                    if (position.globalPosition.dx > screenWidth - 100) {
                      progressThumbnailPosition = screenWidth - 180;
                    } else {
                      progressThumbnailPosition =
                          position.globalPosition.dx - 80;
                    }
                  } else {
                    progressThumbnailPosition = 20;
                  }

                  // FIXME: ProgressThumbnails flicker when loaded the first time from memory
                  // FIXME: Invalid image data when loading a real progress thumbnail for the first time
                  setState(() {});
                },
          // This function is called when the user lets go
          onDragEnd: !enableProgressThumbnails
              ? null
              : () {
                  logger.d("Drag end, hiding progress image");
                  setState(() {
                    hidePlayControls = false;
                    showProgressThumbnail = false;
                  });
                  // start hiding the overlay
                  hideControlsOverlay();
                },
          // TODO: Possibly make TimeLabels in Youtube style
          timeLabelLocation: TimeLabelLocation.sides,
          timeLabelTextStyle:
              const TextStyle(color: Colors.white, fontSize: 16),
          thumbGlowRadius: 0.0,
          // TODO: Find a way to increase the hitbox without increasing the thumb radius
          thumbRadius: 6.0,
          barCapShape: BarCapShape.square,
          barHeight: 2.0,
          // set baseBarColor to white, with low opacity
          baseBarColor: Colors.white.withValues(alpha: 0.2),
          progressBarColor: Theme.of(context).colorScheme.primary,
          bufferedBarColor: Colors.grey.withValues(alpha: 0.5),
          thumbColor: Theme.of(context).colorScheme.primary,
          progress: player.state.position,
          buffered: player.state.buffer,
          total: player.state.duration,
          onSeek: (duration) async => await player.seek(duration),
        ));
  }

  Widget buildSkipWidget() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Padding(
          padding: const EdgeInsets.only(right: 100),
          child: OverlayWidget(
              showControls: showControls && !hidePlayControls,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Colors.black.withValues(alpha: 0.2),
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
                    logger.d(currentTime.inSeconds);
                    logger.d("Skipping by: $skipBy");
                    if (currentTime.inSeconds > skipBy) {
                      // multiply by -1 to skip backwards
                      newTime = currentTime + Duration(seconds: skipBy * -1);
                    }
                    logger.d("Seeking to: $newTime");
                    player.seek(newTime);
                  },
                ),
              ))),
      Padding(
          padding: const EdgeInsets.only(left: 100),
          child: OverlayWidget(
              showControls: showControls && !hidePlayControls,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Colors.black.withValues(alpha: 0.2),
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
                    player.seek(newTime);
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
            child: child));
  }
}
