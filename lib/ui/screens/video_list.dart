import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/database_manager.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/screens/debug_screen.dart';
import 'package:hedon_viewer/ui/screens/video_player/video_player.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

class VideoList extends StatefulWidget {
  final Future<List<UniversalSearchResult>> videoResults;

  const VideoList({super.key, required this.videoResults});

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  VideoPlayerController previewVideoController =
      VideoPlayerController.networkUrl(Uri.parse(""));
  int? _tappedChildIndex;
  bool isLoadingResults = true;

  // List with 10 empty UniversalSearchResults
  // Needed as below some objects will try to read the values from it, even while loading
  List<UniversalSearchResult> videoResults = List.filled(
      12,
      UniversalSearchResult(
          videoID: '',
          title: "\n Word Word",
          provider: null,
          author: "Word Word Word",
          viewsTotal: 100,
          ratingsPositivePercent: 10));

  /// Convert raw views into a human readable format, e.g. 100k
  /// Division will automatically round the number up/down
  /// This function might need to be moved somewhere more generic to allow it to be reused
  String convertViewsIntoHumanReadable(int views) {
    if (views < 1000) {
      return views.toString();
      // <100k
    } else if (views < 100000) {
      return "${(views / 1000).toStringAsFixed(1)}K";
      // <1M
    } else if (views < 1000000) {
      return "${(views / 1000).toStringAsFixed(0)}K";
      // <10M
    } else if (views < 10000000) {
      return "${(views / 1000000).toStringAsFixed(1)}M";
      // >10M
    } else {
      return "${(views / 1000000).toStringAsFixed(0)}M";
    }
  }

  @override
  void initState() {
    super.initState();
    widget.videoResults.whenComplete(() async {
      isLoadingResults = false;
      videoResults = await widget.videoResults;
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    previewVideoController.dispose();
  }

  void setPreviewSource(int index) {
    previewVideoController =
        VideoPlayerController.networkUrl(videoResults[index].videoPreview);
    previewVideoController.initialize().then((value) {
      // previews typically don't have audio, but set to 0 just in case
      previewVideoController.setVolume(0);
      previewVideoController.play();
      previewVideoController.setLooping(true);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    TextStyle smallElementStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: Theme.of(context).colorScheme.tertiary);
    return videoResults.isEmpty
        ? Center(
            child: Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.5),
            child: const Text(
              "No results found",
              style: TextStyle(fontSize: 20),
            ),
          ))
        : GridView.builder(
            padding: const EdgeInsets.all(4.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
              // TODO: Fix horizontal mode card size
              // childAspectRatio: 1.3
            ),
            itemCount: videoResults.length,
            itemBuilder: (context, index) {
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
                                            debugObject: videoResults[index]
                                                .convertToMap()))).then(
                                    (value) => Navigator.of(context).pop());
                              },
                            )
                          ],
                        );
                      },
                    );
                  },
                  onTapDown: (_) {
                    if (sharedStorage.getBool("play_previews_video_list")! ==
                        false) {
                      print("Previews disabled, not playing");
                      return;
                      // if user clicks the same preview again, dont reload
                    } else if (_tappedChildIndex != index) {
                      _tappedChildIndex = index;
                      setState(() {});
                      setPreviewSource(index);
                    }
                  },
                  onTap: () async {
                    // stop playback of preview
                    _tappedChildIndex = null;
                    setState(() {
                      DatabaseManager.addToWatchHistory(videoResults[index]);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoMetadata: videoResults[index]
                                .provider!
                                .getVideoMetadata(videoResults[index].videoID),
                          ),
                        ),
                      );
                    });
                  },
                  child: Skeletonizer(
                      enabled: isLoadingResults,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: const ContinuousRectangleBorder(),
                        elevation: 2.0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ClipRect contains the shadow spreads to just the preview
                                ClipRect(
                                    child: Stack(children: [
                                  SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxWidth * 9 / 16,
                                      child: Skeleton.replace(
                                          // TODO: Detect if video is not visible and stop playing
                                          child: previewVideoController.value
                                                          .isInitialized ==
                                                      true &&
                                                  _tappedChildIndex == index
                                              ? VideoPlayer(
                                                  previewVideoController)
                                              : videoResults[index].thumbnail !=
                                                      ""
                                                  ? Image.network(
                                                      videoResults[index]
                                                          .thumbnail,
                                                      fit: BoxFit.fill)
                                                  : const Placeholder())),
                                  // show video quality
                                  if (videoResults[index].maxQuality != -1) ...[
                                    Positioned(
                                        right: 2.0,
                                        top: 2.0,
                                        child: Container(
                                            padding: const EdgeInsets.only(
                                                left: 2.0, right: 2.0),
                                            decoration: BoxDecoration(
                                                color: isLoadingResults
                                                    ? Colors.transparent
                                                    : Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(4.0),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black45,
                                                    spreadRadius: 3,
                                                    blurRadius: 8,
                                                  ),
                                                ]),
                                            child: Text(
                                              "${videoResults[index].maxQuality}p",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            )))
                                  ],
                                  Positioned(
                                      right: 2.0,
                                      bottom: 2.0,
                                      child: Container(
                                          padding: const EdgeInsets.only(
                                              left: 2.0, right: 2.0),
                                          decoration: BoxDecoration(
                                              color: isLoadingResults
                                                  ? Colors.transparent
                                                  : Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(4.0),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black45,
                                                  spreadRadius: 3,
                                                  blurRadius: 8,
                                                ),
                                              ]),
                                          child: Text(
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              videoResults[index]
                                                          .duration
                                                          .inMinutes <
                                                      61
                                                  ? "${(videoResults[index].duration.inMinutes % 60).toString().padLeft(2, '0')}:${(videoResults[index].duration.inSeconds % 60).toString().padLeft(2, '0')}"
                                                  : "1h+")))
                                ])),
                                Padding(
                                    padding: const EdgeInsets.only(
                                        right: 8, left: 8, top: 2),
                                    child: Text(
                                      // make sure the text is at least 2 lines, so that other widgets dont move up
                                      videoResults[index].title + '\n',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    )),
                                Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(children: [
                                      Row(children: [
                                        Skeleton.shade(
                                            child: Icon(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                                Icons.remove_red_eye)),
                                        const SizedBox(width: 5),
                                        Text(
                                            convertViewsIntoHumanReadable(
                                                videoResults[index].viewsTotal),
                                            style: smallElementStyle)
                                      ]),
                                      Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, right: 8.0),
                                          child: Row(children: [
                                            Skeleton.shade(
                                                child: Icon(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                                    Icons.thumb_up)),
                                            const SizedBox(width: 5),
                                            Text(
                                              videoResults[index]
                                                          .ratingsPositivePercent !=
                                                      -1
                                                  ? "${videoResults[index].ratingsPositivePercent}%"
                                                  : "-",
                                              style: smallElementStyle,
                                            )
                                          ])),
                                      Expanded(
                                          child: Row(children: [
                                        Skeleton.shade(
                                            child: Stack(children: [
                                          Icon(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary,
                                              Icons.person),
                                          videoResults[index].verifiedAuthor
                                              ? const Positioned(
                                                  right: -1.2,
                                                  bottom: -1.2,
                                                  child: Icon(
                                                      size: 16,
                                                      color: Colors.blue,
                                                      Icons.verified))
                                              : const SizedBox(),
                                        ])),
                                        const SizedBox(width: 5),
                                        Expanded(
                                            child: Text(
                                                videoResults[index].author,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: smallElementStyle))
                                      ]))
                                    ]))
                              ],
                            );
                          },
                        ),
                      )));
            },
          );
  }
}
