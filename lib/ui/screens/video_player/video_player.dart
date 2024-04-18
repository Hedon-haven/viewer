import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/screens/debug_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_widget.dart';
import 'progress_widget.dart';
import 'quality_widget.dart';
import 'skip_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: false,
      ));
  Timer? hideControlsTimer;
  bool showControls = false;
  bool isFullScreen = false;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];
  UniversalVideoMetadata videoMetadata = UniversalVideoMetadata(
      videoID: 'none',
      m3u8Uris: {},
      title: List<String>.filled(10, 'title').join(), // long string
      provider: null);

  @override
  void initState() {
    super.initState();
    // make sure the progress bar is updated
    player.stream.position.listen(
      (_) {
        setState(() {});
      },
    );

    // make sure displays update after video is done buffering
    player.stream.buffering.listen(
      (_) {
        setState(() {});
      },
    );

    widget.videoMetadata.whenComplete(() async {
      videoMetadata = await widget.videoMetadata;
      setState(() {
        isLoadingMetadata = false;
      });
      // fix hls playback issues
      if (player.platform is NativePlayer) {
        print("setting them options");
        await (player.platform as dynamic).setProperty(
          'demuxer-lavf-o',
          'live_start_index=0',
        );
      }
      initVideoPlayer();
    });
  }

  void initVideoPlayer() {
    // read preferred video quality setting
    int preferredQuality = sharedStorage.getInt("preferred_video_quality")!;
    selectedResolution = preferredQuality;

    if (videoMetadata.virtualReality) {
      videoMetadata.provider
          ?.displayError("Virtual reality videos not yet supported");
      Navigator.pop(context);
    }

    if (videoMetadata.m3u8Uris.length > 1) {
      // select the preferred quality, or the closest to it

      // Sort the available resolutions in ascending order
      sortedResolutions = videoMetadata.m3u8Uris.keys.toList()..sort();

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
    if (videoMetadata.m3u8Uris[selectedResolution] == null) {
      videoMetadata.provider
          ?.displayError("Coudlnt play video: M3U8 url not found");
      // go back a screen
      Navigator.pop(context);
    }
    initVideoController(videoMetadata.m3u8Uris[selectedResolution]!);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void initVideoController(Uri url) async {
    final bool isPlaying = player.state.playing;
    final oldPosition = player.state.position;
    print("Old position: $oldPosition");
    print("Setting new url: ${url.toString()}");
    await player.open(Media(url.toString()), play: false);
    //await player.open(Media("http://192.168.0.69:8000/1080p.av1.mp4.m3u8"), play: false);

    if (firstPlay) {
      firstPlay = false;
      if (sharedStorage.getBool("start_in_fullscreen")!) {
        print("Full-screening video as per settings");
        toggleFullScreen();
      }
      if (sharedStorage.getBool("auto_play")!) {
        print("Autostarting video as per settings");
        player.play();
        hideControlsOverlay();
        return; // return, so that controls arent automatically shown
      }
      // only show controls after controller is fully done initializing
      showControls = true;
    }
    if (isPlaying) {
      player.play();
    }
  }

  void hideControlsOverlay() {
    hideControlsTimer?.cancel(); // stop any old timers
    hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        showControls = false;
      });
    });
  }

  void showControlsOverlay() {
    if (firstPlay) {
      // refuse to show controls while video is initializing the first time
      return;
    }
    // Check if hideControlsTimer is empty, so that the isActive check doesnt throw a null error
    if (hideControlsTimer != null && player.state.playing) {
      if (!hideControlsTimer!.isActive) {
        hideControlsOverlay();
      }
    } else {
      hideControlsTimer?.cancel();
    }
    setState(() {
      showControls = !showControls;
    });
  }

  void playPausePlayer() {
    setState(() {
      if (player.state.playing) {
        player.pause();
        WakelockPlus.disable();
        hideControlsTimer?.cancel();
      } else {
        print("Current player position: ${player.state.position}");
        player.play();
        print("Current new player position: ${player.state.position}");
        WakelockPlus.enable();
        hideControlsOverlay();
      }
    });
  }

  void toggleFullScreen() {
    // the windowManager is just for desktop. It wont interfere with mobile
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: PopScope(
                // only allow pop if not in fullscreen
                canPop: !isFullScreen,
                onPopInvoked: (goingToPop) {
                  print("Pop invoked, goingToPop: $goingToPop");
                  // immediately stop video if popping
                  if (goingToPop) {
                    player.pause();
                  }
                  // restore upright orientation
                  if (isFullScreen) {
                    toggleFullScreen();
                  }
                },
                child: Skeletonizer(
                    enabled: isLoadingMetadata,
                    child: Column(children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).orientation ==
                                Orientation.landscape
                            ? MediaQuery.of(context).size.height
                            : MediaQuery.of(context).size.width * 9 / 16,
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
                                                builder: (context) => BugReportScreen(
                                                    debugObject: videoMetadata
                                                        .convertToMap()))).then(
                                            (value) =>
                                                Navigator.of(context).pop());
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
                                    (isFullScreen ? 1 : -1) >
                                0) {
                              toggleFullScreen();
                            }
                          },
                          child: Container(
                              // add a background to be able to switch to pitch-black when in fullscreen
                              color: isFullScreen
                                  ? Colors.black
                                  : Colors.transparent,
                              child: SizedBox(
                                height: MediaQuery.of(context).orientation ==
                                        Orientation.landscape
                                    ? MediaQuery.of(context).size.height
                                    : MediaQuery.of(context).size.width *
                                        9 /
                                        16,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    // the video widget itself
                                    AspectRatio(
                                      // This makes the video 16:9 while loading -> skeleton looks weird otherwise
                                      aspectRatio: player.state.width != null
                                          ? (player.state.width! /
                                              player.state.height!)
                                          : 16 / 9,
                                      child: Skeleton.replace(
                                          child: isLoadingMetadata
                                              ? const Placeholder()
                                              : Video(
                                                  controller: controller,
                                                  controls: NoVideoControls)),
                                    ),
                                    // gray background to make buttons more visible when overlay is on
                                    OverlayWidget(
                                      showControls: showControls,
                                      child: Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ),
                                    SkipWidget(
                                        showControls: showControls,
                                        player: player,
                                        skipBy: sharedStorage
                                            .getInt("seek_duration")!),
                                    OverlayWidget(
                                      showControls: showControls,
                                      child: player.state.buffering &&
                                              !player.state.playing &&
                                              !player.state.completed
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
                                    // TODO: Show back button while skeletonizer is running
                                    Positioned(
                                        top: 5,
                                        left: 5,
                                        child: OverlayWidget(
                                            showControls: showControls,
                                            child: IconButton(
                                                color: Colors.white,
                                                icon: const Icon(
                                                    Icons.arrow_back),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                }))),
                                    Positioned(
                                        top: 5,
                                        right: 10,
                                        child: QualityWidget(
                                          showControls: showControls,
                                          selectedResolution:
                                              selectedResolution,
                                          onSelected: (newResolution) {
                                            selectedResolution = newResolution;
                                            initVideoController(videoMetadata
                                                .m3u8Uris[selectedResolution]!);
                                          },
                                          sortedResolutions: sortedResolutions,
                                        )),
                                    Positioned(
                                      bottom: 5.0,
                                      left: 20.0,
                                      right: 0.0,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: <Widget>[
                                            Expanded(
                                              child: ProgressBarWidget(
                                                showControls: showControls,
                                                player: player,
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
                              )),
                        ),
                      ),
                      // only show the following widgets if not in fullscreen
                      if (!isFullScreen) ...[
                        Column(children: <Widget>[
                          // make sure the text element takes up the whole available space
                          SizedBox(
                              width: double.infinity,
                              child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8, left: 10, right: 10),
                                  child: Text(videoMetadata.title,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2))),
                        ])
                      ]
                    ])))));
  }
}

// Browser button:
// OverlayWidget(
//                                   showControls: showControls,
//                                   child: IconButton(
//                                     color: Colors.white,
//                                     icon: const Icon(Icons.open_in_browser),
//                                     onPressed: () async {
//                                       await launchUrl(Uri.parse(videoMetadata
//                                               .pluginOrigin!
//                                               .videoEndpoint +
//                                           videoMetadata.videoID));
//                                     },
//                                   ))
