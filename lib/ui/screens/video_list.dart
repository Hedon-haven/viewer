import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:html/dom.dart' show Document;
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

import '/services/database_manager.dart';
import '/services/loading_handler.dart';
import '/services/plugin_manager.dart';
import '/ui/screens/bug_report.dart';
import '/ui/screens/settings/settings_plugins.dart';
import '/ui/screens/video_screen/video_screen.dart';
import '/ui/utils/toast_notification.dart';
import '/utils/convert.dart';
import '/utils/global_vars.dart';
import '/utils/plugin_interface.dart';
import '/utils/universal_formats.dart';

class VideoList extends StatefulWidget {
  Future<List<UniversalVideoPreview>?> videoList;

  /// Type of list. Possible types: "history", "downloads", "results", "homepage", "favorites", "suggestions"
  final String listType;

  /// Don't pad the video list (other padding might still apply)
  final bool noListPadding;

  final Future<List<UniversalVideoPreview>?> Function()? loadMoreResults;

  // Not all listTypes require all of these variables -> make all of them nullable
  late LoadingHandler? loadingHandler;
  late UniversalSearchRequest? searchRequest;
  late PluginInterface? plugin;
  late String? videoID;
  late Document? rawHtml;

  VideoList(
      {super.key,
      required this.videoList,
      required this.listType,
      required this.loadMoreResults,
      this.noListPadding = false,
      this.loadingHandler,
      this.searchRequest,
      this.plugin,
      this.videoID,
      this.rawHtml});

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
  List<UniversalVideoPreview>? videoList =
      List.filled(12, UniversalVideoPreview.skeleton());

  @override
  void initState() {
    super.initState();

    // init listView type
    sharedStorage
        .getString("appearance_list_view")
        .then((value) => setState(() => listViewValue = value!));

    logger.d("Screen type: ${widget.listType}");
    scrollController.addListener((scrollListener));
    getApplicationCacheDirectory().then((value) {
      cacheDir = Directory("${value.path}/icons");
    });
    loadVideoResults();

    // Check if plugins are enabled if listType is homepage or results
    if (widget.listType == "homepage") {
      noPluginsEnabled = PluginManager.enabledHomepageProviders.isEmpty;
      logger.d("No homepage providers enabled: $noPluginsEnabled");
    } else if (widget.listType == "results") {
      noPluginsEnabled = PluginManager.enabledResultsProviders.isEmpty;
      logger.d("No results providers enabled: $noPluginsEnabled");
    }

    logger.i("Finished initializing screen");
  }

  @override
  void dispose() {
    logger.i("Disposing of VideoList");
    previewVideoController.pause().then((_) {
      previewVideoController.dispose();
    });
    scrollController.dispose();
    // Depending on list type cancel the loading handler
    switch (widget.listType) {
      case "homepage":
        widget.loadingHandler!.cancelGetHomePages();
        break;
      case "results":
        widget.loadingHandler!.cancelGetSearchResults();
        break;
      case "suggestions":
        widget.loadingHandler!.cancelGetVideoSuggestions();
        break;
      default:
        logger.w("List type doesn't support canceling loading handler");
        break;
    }
    super.dispose();
  }

  void loadVideoResults() async {
    setState(() {
      isLoadingResults = true;
    });
    videoList = await widget.videoList;
    // If Connectivity contains ConnectivityResult.none -> no internet connection -> revert results
    isInternetConnected = !(await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none);
    logger.d("Internet connected: $isInternetConnected");
    // Make sure context is still mounted
    if (mounted) setState(() => isLoadingResults = false);
  }

  void scrollListener() async {
    if (!isLoadingMoreResults &&
        scrollController.position.pixels >=
            0.95 * scrollController.position.maxScrollExtent) {
      logger.i("Loading additional results");
      setState(() => isLoadingMoreResults = true);
      Future<List<UniversalVideoPreview>?> newVideoResults = Future.value([]);
      if (widget.loadMoreResults == null) {
        logger.d(
            "List type doesn't support loading more results. Not loading anything...");
        newVideoResults = Future.value(videoList);
      } else {
        newVideoResults = widget.loadMoreResults!();
      }

      videoList = await newVideoResults;
      logger.i("Finished getting more results");
      setState(() => isLoadingMoreResults = false);
    }
  }

  void setPreviewSource(int index) {
    if (videoList![index].previewVideo == null) {
      logger.i("Preview URI empty, not playing");
      return;
    }
    previewVideoController.dispose();
    previewVideoController =
        VideoPlayerController.networkUrl(videoList![index].previewVideo!);
    previewVideoController.initialize().then((value) async {
      // FIXME: This doesn't work, the video still has sound
      // Create a bug report upstream
      await previewVideoController.setVolume(0.0);
      await previewVideoController.setLooping(true);
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
    if ((await sharedStorage.getBool("appearance_play_previews"))! == false) {
      logger.i("Preview setting disabled, not playing");
      return;
    } else if (!["homepage", "results", "suggestions"]
        .contains(widget.listType)) {
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
    // If the list is null -> error
    // If the list is empty -> no results, but no error getting them either
    return (videoList?.isEmpty ?? true) && !isLoadingResults
        ? Center(child: LayoutBuilder(builder: (context, constraints) {
            return Padding(
                padding: EdgeInsets.only(
                    left: constraints.maxWidth * 0.05,
                    right: constraints.maxWidth * 0.05,
                    bottom: constraints.maxHeight * 0.5),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 50, bottom: 30),
                      child: Text(
                          // Null means error
                          videoList == null
                              ? switch (widget.listType) {
                                  "history" => "Watch history disabled",
                                  "results" => noPluginsEnabled
                                      ? "No result providers enabled. Enable at least one plugin's result provider setting"
                                      : isInternetConnected
                                          ? "Error loading results"
                                          : "No internet connection",
                                  "homepage" => noPluginsEnabled
                                      ? "No homepage providers enabled. Enable at least one plugin's homepage provider setting"
                                      : isInternetConnected
                                          ? "Error loading homepage"
                                          : "No internet connection",
                                  "downloads" => "Error getting downloads",
                                  "favorites" => "Error getting favorites",
                                  "suggestions" =>
                                    "Error getting video suggestions",
                                  _ =>
                                    "UNKNOWN SCREEN TYPE (null error), REPORT TO DEVELOPERS!!!",
                                }
                              // non-null but empty means no results
                              : switch (widget.listType) {
                                  "history" => "No watch history yet",
                                  "results" => "No results found",
                                  // Homepage cant be empty without error
                                  "homepage" =>
                                    "UNKNOWN ERROR!!! REPORT TO DEVELOPERS!!!",
                                  "downloads" => "No downloads yet",
                                  "favorites" => "No favorites yet",
                                  "suggestions" => "No video suggestions found",
                                  _ =>
                                    "UNKNOWN SCREEN TYPE (empty success), REPORT TO DEVELOPERS!!!",
                                },
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center)),
                  if (noPluginsEnabled) ...[
                    ElevatedButton(
                        style: TextButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary),
                        child: Text("Open plugin settings",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary)),
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PluginsScreen(),
                              ));
                          // Reload video results

                          switch (widget.listType) {
                            case "homepage":
                              widget.videoList = widget.loadingHandler!
                                  .getHomePages(videoList);
                              break;
                            case "results":
                              widget.videoList = widget.loadingHandler!
                                  .getSearchResults(
                                      widget.searchRequest!, videoList);
                              break;
                            default:
                              logger.e(
                                  "Unknown list type: ${widget.listType} after"
                                  " returning from plugin settings");
                              break;
                          }
                          loadVideoResults();
                        })
                  ]
                ]));
          }))
        : MasonryGridView.count(
            crossAxisCount: listViewValue == "Grid" ? 2 : 1,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            controller: scrollController,
            padding: widget.noListPadding
                ? EdgeInsets.zero
                : const EdgeInsets.only(right: 15, left: 15),
            //  itemCount: videoResults.length // + (isLoadingMoreResults ? 10 : 0),
            // In rare cases this null check fails -> make sure its always at least 0
            itemCount: videoList?.length ?? 0,
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
                                          videoList![index].iD),
                                      builder: (context, snapshot) {
                                        return ListTile(
                                          leading: Icon(snapshot.data ?? false
                                              ? Icons.favorite
                                              : Icons.favorite_border),
                                          title: Text(snapshot.data ?? false
                                              ? "Remove from favorites"
                                              : "Add to favorites"),
                                          onTap: () async {
                                            if (snapshot.data == null) return;
                                            if (snapshot.data!) {
                                              await removeFromFavorites(
                                                  videoList![index]);
                                            } else {
                                              await addToFavorites(
                                                  videoList![index]);
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
                                              debugObject: [
                                                videoList![index].convertToMap()
                                              ]),
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
                        if (videoList![index].virtualReality) {
                          showToast(
                              "Virtual reality not yet supported", context);
                          return;
                        }
                        addToWatchHistory(videoList![index], widget.listType);
                        previewVideoController
                            .dispose()
                            .then((_) => setState(() => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayerScreen(
                                      videoMetadata: videoList![index]
                                          .plugin!
                                          .getVideoMetadata(
                                              videoList![index].iD,
                                              videoList![index]),
                                    ),
                                  ),
                                )));
                      },
                      child: Skeletonizer(
                        enabled: isLoadingResults || index >= videoList!.length,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return IntrinsicHeight(
                                child: Flex(
                              mainAxisSize: MainAxisSize.min,
                              direction: listViewValue == "List"
                                  ? Axis.horizontal
                                  : Axis.vertical,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildImageWidgets(constraints, index),
                                buildDescription(index),
                              ],
                            ));
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
                    : ["homepage", "results", "suggestions"]
                            .contains(widget.listType)
                        ? Image.network(
                            videoList![index].thumbnail ??
                                "Thumbnail url is null",
                            errorBuilder: (context, error, stackTrace) {
                            logger.e(
                                "Failed to load network thumbnail: $error\n$stackTrace");
                            return Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                            );
                          }, fit: BoxFit.fill)
                        : Image.memory(videoList![index].thumbnailBinary,
                            errorBuilder: (context, error, stackTrace) {
                            logger.e(
                                "Failed to load binary thumbnail: $error\n$stackTrace");
                            return Icon(
                              Icons.nearby_error,
                              color: Theme.of(context).colorScheme.error,
                            );
                          }, fit: BoxFit.fill),
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
          if (videoList![index].maxQuality != null) ...[
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
                      !videoList![index].virtualReality
                          ? "${videoList![index].maxQuality}p"
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
                      videoList![index].duration?.inMinutes == null
                          ? "??:??"
                          : videoList![index].duration!.inMinutes < 61
                              ? "${(videoList![index].duration!.inMinutes % 60).toString().padLeft(2, '0')}:${(videoList![index].duration!.inSeconds % 60).toString().padLeft(2, '0')}"
                              : "1h+"))),
          Positioned(
              left: 4.0,
              top: 4.0,
              child: Skeleton.replace(
                  child: !isLoadingResults
                      ? Image.file(
                          File(
                              "${cacheDir?.path}/${videoList![index].plugin?.codeName}"),
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
                videoList![index].title,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(children: [
                Text(
                    videoList![index].viewsTotal == null
                        ? "-"
                        : "${convertNumberIntoHumanReadable(videoList![index].viewsTotal!)} ",
                    maxLines: 1,
                    style: smallTextStyle),
                Skeleton.shade(
                    child: Icon(
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                        Icons.remove_red_eye)),
                const SizedBox(width: 5),
                Text(
                    "| ${videoList![index].ratingsPositivePercent == null ? "-" : "${videoList![index].ratingsPositivePercent}%"}",
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
                  videoList![index].verifiedAuthor
                      ? const Positioned(
                          right: -1.2,
                          bottom: -1.2,
                          child: Icon(
                              size: 16, color: Colors.blue, Icons.verified))
                      : const SizedBox(),
                ])),
                const SizedBox(width: 5),
                Expanded(
                    child: Text(videoList![index].author ?? "Unknown author",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: smallTextStyle))
              ])
            ])));
  }
}
