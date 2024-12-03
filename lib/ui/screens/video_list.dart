import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/loading_handler.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/debug_screen.dart';
import '/ui/screens/video_screen/video_screen.dart';
import '/ui/toast_notification.dart';

class VideoList extends StatefulWidget {
  Future<List<UniversalVideoPreview>> videoResults;

  /// Type of list. Possible types: "history", "downloads", "results", "homepage", "favorites"
  final String listType;
  late LoadingHandler? loadingHandler;
  late UniversalSearchRequest? searchRequest;

  VideoList(
      {super.key,
      required this.videoResults,
      required this.listType,
      required this.loadingHandler,
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
  bool noPluginsEnabled = false;
  String listViewValue = "Card";

  Directory? cacheDir;

  // List with 10 empty UniversalSearchResults
  // Needed as below some objects will try to read the values from it, even while loading
  List<UniversalVideoPreview> videoResults = List.filled(
      12,
      UniversalVideoPreview(
        videoID: '',
        plugin: null,
        thumbnail: "",
        title: BoneMock.paragraph,
        viewsTotal: 100,
        maxQuality: 100,
        ratingsPositivePercent: 10,
        author: BoneMock.name,
      ));

  @override
  void initState() {
    super.initState();

    // init listView type
    sharedStorage
        .getString("list_view")
        .then((value) => setState(() => listViewValue = value!));

    logger.d("Screen type: ${widget.listType}");
    scrollController.addListener((scrollListener));
    getApplicationCacheDirectory().then((value) {
      cacheDir = Directory("${value.path}/icons");
    });
    widget.videoResults.whenComplete(() async {
      try {
        videoResults = await widget.videoResults;
        // If Connectivity contains ConnectivityResult.none -> no internet connection -> revert results
        isInternetConnected = !(await (Connectivity().checkConnectivity()))
            .contains(ConnectivityResult.none);
        logger.d("Internet connected: $isInternetConnected");
        setState(() {
          isLoadingResults = false;
        });
      } catch (e) {
        if (e is Exception &&
            e.toString().contains(
                "No provider/plugins provided or configured in settings")) {
          logger.w(
              "No provider/plugins provided or configured in settings, cannot load results");
          setState(() {
            videoResults = []; // set to empty
            noPluginsEnabled = true;
            isLoadingResults = false;
          });
        } else {
          logger.d("Rethrowing exception: $e");
          rethrow;
        }
      }
    });
  }

  void scrollListener() async {
    if (!isLoadingMoreResults &&
        widget.loadingHandler != null &&
        scrollController.position.pixels >=
            0.95 * scrollController.position.maxScrollExtent) {
      logger.i("Loading additional results");
      isLoadingMoreResults = true;
      Future<List<UniversalVideoPreview>> newVideoResults = widget
          .loadingHandler!
          .getSearchResults(widget.searchRequest, videoResults);
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
    if (videoResults[index].previewVideo == null) {
      logger.i("Preview URI empty, not playing");
      return;
    }
    previewVideoController =
        VideoPlayerController.networkUrl(videoResults[index].previewVideo!);
    previewVideoController.initialize().then((value) {
      // previews typically don't have audio, but set to 0 just in case
      previewVideoController.setVolume(0.0);
      previewVideoController.setLooping(true);
      setState(() {
        previewVideoController.play();
      });
    });
  }

  void showPreview(int index) async {
    if (isLoadingResults) {
      logger.i("Still loading results, not playing");
      return;
    }
    if ((await sharedStorage.getBool("play_previews_video_list"))! == false) {
      logger.i("Preview setting disabled, not playing");
      return;
    } else if (!["homepage", "results"].contains(widget.listType)) {
      logger.i(
          "List Type (${widget.listType}) does not support previews, not playing");
      return;
    }
    // if user clicks the same preview again, don't reload
    else if (_tappedChildIndex != index) {
      setState(() {
        _tappedChildIndex = index;
        setPreviewSource(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return videoResults.isEmpty && !isLoadingResults
        ? Center(
            child: Container(
                padding: EdgeInsets.only(
                    left: MediaQuery.of(context).size.width * 0.05,
                    right: MediaQuery.of(context).size.width * 0.05,
                    bottom: MediaQuery.of(context).size.height * 0.5),
                child: FutureBuilder<bool?>(
                    future: sharedStorage.getBool("enable_watch_history"),
                    builder: (context, snapshot) {
                      // only build when data finished loading
                      if (snapshot.data == null) {
                        return const SizedBox();
                      }
                      return Text(
                          noPluginsEnabled
                              ? "No homepage providers enabled. Go to Settings -> Plugins and enable at least one plugin's homepage provider setting"
                              : switch (widget.listType) {
                                  "history" => snapshot.data!
                                      ? "No watch history yet"
                                      : "Watch history disabled",
                                  "results" => isInternetConnected
                                      ? "No internet connection"
                                      : "No results found",
                                  "homepage" => isInternetConnected
                                      ? "No internet connection"
                                      : "Error loading homepage",
                                  "downloads" => "No downloads found",
                                  "favorites" => "No favorites yet",
                                  _ =>
                                    "UNKNOWN SCREEN TYPE, REPORT TO DEVELOPERS!!!",
                                },
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center);
                    })))
        : GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(right: 15, left: 15),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: listViewValue == "Grid" ? 2 : 1,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              // TODO: Find a way to set individual aspect ratios
              childAspectRatio: listViewValue == "Grid"
                  ? 0.96
                  : listViewValue == "Card"
                      ? 1.24
                      : 3.5,
            ),
            //  itemCount: videoResults.length // + (isLoadingMoreResults ? 10 : 0),
            itemCount: videoResults.length,
            itemBuilder: (context, index) {
              return MouseRegion(
                  onEnter: (_) => showPreview(index),
                  child: GestureDetector(
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            // Use stateful builder to allow calling setState on the modal itself
                            return StatefulBuilder(
                              builder: (BuildContext context,
                                  StateSetter setModalState) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    FutureBuilder<bool?>(
                                      future: isInFavorites(
                                          videoResults[index].videoID),
                                      builder: (context, snapshot) {
                                        if (snapshot.data == null) {
                                          return const SizedBox();
                                        }
                                        return ListTile(
                                          leading: Icon(snapshot.data!
                                              ? Icons.favorite
                                              : Icons.favorite_border),
                                          title: Text(snapshot.data!
                                              ? "Remove from favorites"
                                              : "Add to favorites"),
                                          onTap: () async {
                                            if (snapshot.data!) {
                                              await removeFromFavorites(
                                                  videoResults[index]);
                                            } else {
                                              await addToFavorites(
                                                  videoResults[index]);
                                            }
                                            // Rebuild the modal's UI
                                            setModalState(() {});
                                          },
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.bug_report),
                                      title: const Text("Create bug report"),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BugReportScreen(
                                              debugObject: videoResults[index]
                                                  .convertToMap()),
                                        ),
                                      ).then((value) =>
                                          Navigator.of(context).pop()),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                      onTapDown: (_) => showPreview(index),
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
                        addToWatchHistory(videoResults[index], widget.listType);
                        setState(() {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                videoMetadata: videoResults[index]
                                    .plugin!
                                    .getVideoMetadata(
                                        videoResults[index].videoID),
                              ),
                            ),
                          );
                        });
                      },
                      child: Skeletonizer(
                        enabled:
                            isLoadingResults || index >= videoResults.length,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Flex(
                              direction: listViewValue == "List"
                                  ? Axis.horizontal
                                  : Axis.vertical,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildImageWidgets(constraints, index),
                                buildDescription(index),
                              ],
                            );
                          },
                        ),
                      )));
            },
          );
  }

  Widget buildImageWidgets(BoxConstraints constraints, int index) {
    // ClipRect contains the shadow spreads to just the preview
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(children: [
          SizedBox(
              // make the image smaller for list view mode
              width: constraints.maxWidth / (listViewValue == "List" ? 2 : 1),
              height: constraints.maxWidth *
                  9 /
                  16 /
                  (listViewValue == "List" ? 2 : 1),
              child: Skeleton.replace(
                // TODO: Detect if video is not visible and stop playing
                child: previewVideoController.value.isInitialized == true &&
                        _tappedChildIndex == index
                    ? VideoPlayer(previewVideoController)
                    : ["homepage", "results"].contains(widget.listType)
                        ? Image.network(videoResults[index].thumbnail ?? "",
                            errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.error,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            fit: BoxFit.fill)
                        : Image.memory(videoResults[index].thumbnailBinary,
                            errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.nearby_error,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                            fit: BoxFit.fill),
              )),
          // Show previewVideo loading progress
          // TODO: Maybe find a way to show the actual progress of the download
          if (previewVideoController.value.isInitialized == false &&
              _tappedChildIndex == index) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return LinearProgressIndicator(value: value);
              },
            )
          ],
          // show video quality
          if (videoResults[index].maxQuality != null) ...[
            Positioned(
                right: 4.0,
                top: 4.0,
                child: Container(
                    padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                    decoration: BoxDecoration(
                        color: isLoadingResults
                            ? Colors.transparent
                            : Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4.0)),
                    child: Text(
                      !videoResults[index].virtualReality
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
                  padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                  decoration: BoxDecoration(
                      color: isLoadingResults
                          ? Colors.transparent
                          : Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4.0)),
                  child: Text(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      videoResults[index].duration?.inMinutes == null
                          ? "??:??"
                          : videoResults[index].duration!.inMinutes < 61
                              ? "${(videoResults[index].duration!.inMinutes % 60).toString().padLeft(2, '0')}:${(videoResults[index].duration!.inSeconds % 60).toString().padLeft(2, '0')}"
                              : "1h+"))),
          Positioned(
              left: 4.0,
              top: 4.0,
              child: Skeleton.replace(
                  child: !isLoadingResults
                      ? Image.file(
                          File(
                              "${cacheDir?.path}/${videoResults[index].plugin?.codeName}"),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.question_mark),
                          width: 20,
                          height: 20)
                      // TODO: Fix skeletonizer not showing
                      : const Placeholder()))
        ]));
  }

  Widget buildDescription(int index) {
    TextStyle smallTextStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: Theme.of(context).colorScheme.tertiary);
    return Expanded(
        child: Padding(
            padding: const EdgeInsets.only(right: 6, left: 6, top: 3),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                // make sure the text is at least 2 lines, so that other widgets dont move up
                videoResults[index].title,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(children: [
                Text(
                    videoResults[index].viewsTotal == null
                        ? "-"
                        : "${convertNumberIntoHumanReadable(videoResults[index].viewsTotal!)} ",
                    maxLines: 1,
                    style: smallTextStyle),
                Skeleton.shade(
                    child: Icon(
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                        Icons.remove_red_eye)),
                const SizedBox(width: 5),
                Text(
                    "| ${videoResults[index].ratingsPositivePercent == null ? "-" : "${videoResults[index].ratingsPositivePercent}%"}",
                    maxLines: 1,
                    style: smallTextStyle),
                const SizedBox(width: 5),
                Skeleton.shade(
                    child: Icon(
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                        Icons.thumb_up)),
              ]),
              Row(children: [
                Skeleton.shade(
                    child: Stack(children: [
                  Icon(
                      color: Theme.of(context).colorScheme.secondary,
                      Icons.person),
                  videoResults[index].verifiedAuthor
                      ? const Positioned(
                          right: -1.2,
                          bottom: -1.2,
                          child: Icon(
                              size: 16, color: Colors.blue, Icons.verified))
                      : const SizedBox(),
                ])),
                const SizedBox(width: 5),
                Expanded(
                    child: Text(videoResults[index].author ?? "Unknown author",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: smallTextStyle))
              ])
            ])));
  }
}
