import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/search_manager.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/debug_screen.dart';
import '/ui/screens/video_screen/video_screen.dart';
import '/ui/toast_notification.dart';

class VideoList extends StatefulWidget {
  Future<List<UniversalSearchResult>> videoResults;

  /// Type of list. Possible types: "history", "downloads", "results"
  final String listType;
  late SearchHandler? searchHandler;
  late UniversalSearchRequest? searchRequest;

  VideoList(
      {super.key,
      required this.videoResults,
      required this.listType,
      required this.searchHandler,
      required this.searchRequest});

  @override
  State<VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  VideoPlayerController previewVideoController =
      VideoPlayerController.networkUrl(Uri.parse(""));
  ScrollController scrollController = ScrollController();
  int? _tappedChildIndex;
  bool isLoadingResults = true;
  bool isLoadingMoreResults = false;
  bool isInternetConnected = true;
  String listViewValue = sharedStorage.getString("list_view")!;
  Directory? cacheDir;

  // List with 10 empty UniversalSearchResults
  // Needed as below some objects will try to read the values from it, even while loading
  List<UniversalSearchResult> videoResults = List.filled(
      12,
      UniversalSearchResult(
          videoID: '',
          plugin: null,
          author: BoneMock.name,
          thumbnail: "",
          title: BoneMock.paragraph,
          viewsTotal: 100,
          maxQuality: 100,
          ratingsPositivePercent: 10));

  @override
  void initState() {
    super.initState();
    scrollController.addListener((scrollListener));
    getApplicationCacheDirectory().then((value) {
      cacheDir = value;
    });
    widget.videoResults.whenComplete(() async {
      videoResults = await widget.videoResults;
      isInternetConnected = (await (Connectivity().checkConnectivity()))
          .contains(ConnectivityResult.none);
      setState(() {
        isLoadingResults = false;
      });
    });
  }

  void scrollListener() async {
    if (!isLoadingMoreResults &&
        widget.searchHandler != null &&
        scrollController.position.pixels >=
            0.95 * scrollController.position.maxScrollExtent) {
      logger.i("Loading additional results");
      isLoadingMoreResults = true;
      Future<List<UniversalSearchResult>> newVideoResults =
          widget.searchHandler!.getResults(widget.searchRequest, videoResults);
      newVideoResults.whenComplete(() async {
        videoResults = await newVideoResults;
        logger.i("Finished getting more results");
        setState(() {
          isLoadingMoreResults = false;
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    previewVideoController.dispose();
    scrollController.dispose();
  }

  void setPreviewSource(int index) {
    if (videoResults[index].videoPreview.hasEmptyPath) {
      logger.i("Preview URI empty, not playing");
      return;
    }
    previewVideoController =
        VideoPlayerController.networkUrl(videoResults[index].videoPreview);
    previewVideoController.initialize().then((value) {
      // previews typically don't have audio, but set to 0 just in case
      previewVideoController.setVolume(0);
      previewVideoController.setLooping(true);
      setState(() {
        previewVideoController.play();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    TextStyle smallTextStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: Theme.of(context).colorScheme.tertiary);
    return videoResults.isEmpty && !isLoadingResults
        ? Center(
            child: Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.5),
            child: Text(
              isInternetConnected || widget.listType != "results"
                  ? switch (widget.listType) {
                      "history" => "No history found",
                      "results" => "No results found",
                      "homepage" => "Homepage unavailable",
                      "downloads" => "No downloads found",
                      _ => "UNKNOWN SCREEN TYPE, REPORT TO DEVELOPERS!!!",
                    }
                  : "No internet connection",
              style: const TextStyle(fontSize: 20),
            ),
          ))
        : GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(right: 15, left: 15),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: listViewValue == "Grid" ? 2 : 1,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: listViewValue == "Grid"
                  ? 0.96
                  : listViewValue == "Card"
                      ? 1.25
                      : 3.5,
            ),
            //  itemCount: videoResults.length // + (isLoadingMoreResults ? 10 : 0),
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
                      logger.i("Previews disabled, not playing");
                      return;
                      // if user clicks the same preview again, dont reload
                    } else if (_tappedChildIndex != index) {
                      setState(() {
                        _tappedChildIndex = index;
                        setPreviewSource(index);
                      });
                    }
                  },
                  onTap: () async {
                    // stop playback of preview
                    // FIXME: Sometimes videoPlayer doesnt dispose and spams errors
                    previewVideoController.pause();
                    previewVideoController.dispose();
                    _tappedChildIndex = null;
                    if (videoResults[index].virtualReality) {
                      ToastMessageShower.showToast(
                          "Virtual reality not yet supported", context);
                      return;
                    }
                    DatabaseManager.addToWatchHistory(
                        videoResults[index], widget.listType);
                    setState(() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoMetadata: videoResults[index]
                                .plugin!
                                .getVideoMetadata(videoResults[index].videoID),
                          ),
                        ),
                      );
                    });
                  },
                  child: Skeletonizer(
                    enabled: isLoadingResults || index >= videoResults.length,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Flex(
                          direction: listViewValue == "List"
                              ? Axis.horizontal
                              : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ClipRect contains the shadow spreads to just the preview
                            ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(children: [
                                  SizedBox(
                                      // make the image smaller for list view mode
                                      width: constraints.maxWidth /
                                          (listViewValue == "List" ? 2 : 1),
                                      height: constraints.maxWidth *
                                          9 /
                                          16 /
                                          (listViewValue == "List" ? 2 : 1),
                                      child: Skeleton.replace(
                                          // TODO: Detect if video is not visible and stop playing
                                          child: previewVideoController.value
                                                          .isInitialized ==
                                                      true &&
                                                  _tappedChildIndex == index
                                              ? VideoPlayer(
                                                  previewVideoController)
                                              : widget.listType == "results"
                                                  ? Image.network(
                                                      videoResults[index]
                                                          .thumbnail,
                                                      fit: BoxFit.fill)
                                                  : Image.memory(
                                                      videoResults[index]
                                                          .thumbnailBinary))),
                                  // show video quality
                                  if (videoResults[index].maxQuality != -1) ...[
                                    Positioned(
                                        right: 4.0,
                                        top: 4.0,
                                        child: Container(
                                            padding: const EdgeInsets.only(
                                                left: 2.0, right: 2.0),
                                            decoration: BoxDecoration(
                                                color: isLoadingResults
                                                    ? Colors.transparent
                                                    : Colors.black
                                                        .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4.0)),
                                            child: Text(
                                              !videoResults[index]
                                                      .virtualReality
                                                  ? "${videoResults[index].maxQuality}p"
                                                  : "VR",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            )))
                                  ],
                                  Positioned(
                                      right: 4.0,
                                      bottom: 4.0,
                                      child: Container(
                                          padding: const EdgeInsets.only(
                                              left: 2.0, right: 2.0),
                                          decoration: BoxDecoration(
                                              color: isLoadingResults
                                                  ? Colors.transparent
                                                  : Colors.black
                                                      .withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(4.0)),
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
                                                  : "1h+"))),
                                  Positioned(
                                      left: 4.0,
                                      top: 4.0,
                                      child: Skeleton.replace(
                                          child: !isLoadingResults
                                              ? Image.file(
                                                  File(
                                                      "${cacheDir?.path}/${videoResults[index].plugin?.name}"),
                                                  width: 20,
                                                  height: 20)
                                              // TODO: Fix skeletonizer not showing
                                              : const Placeholder()))
                                ])),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(
                                        right: 6, left: 6, top: 2),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            // make sure the text is at least 2 lines, so that other widgets dont move up
                                            // TODO: Fix graphical glitch when loading
                                            videoResults[index].title,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Row(children: [
                                            Text(
                                                "${convertViewsIntoHumanReadable(videoResults[index].viewsTotal)} ",
                                                maxLines: 1,
                                                style: smallTextStyle),
                                            Skeleton.shade(
                                                child: Icon(
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                                    Icons.remove_red_eye)),
                                            const SizedBox(width: 5),
                                            Text(
                                                "| ${videoResults[index].ratingsPositivePercent != -1 ? "${videoResults[index].ratingsPositivePercent}%" : "-"}",
                                                maxLines: 1,
                                                style: smallTextStyle),
                                            const SizedBox(width: 5),
                                            Skeleton.shade(
                                                child: Icon(
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                                    Icons.thumb_up)),
                                          ]),
                                          Row(children: [
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
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: smallTextStyle))
                                          ])
                                        ])))
                          ],
                        );
                      },
                    ),
                  ));
            },
          );
  }
}
