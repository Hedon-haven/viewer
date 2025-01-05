import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:window_manager/window_manager.dart';

import '/services/loading_handler.dart';
import '/ui/screens/settings/settings_comments.dart';
import '/ui/screens/video_list.dart';
import '/ui/screens/video_screen/player_widget.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';
import '../../utils/toast_notification.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Future<UniversalVideoMetadata> videoMetadata;

  const VideoPlayerScreen({super.key, required this.videoMetadata});

  @override
  State<VideoPlayerScreen> createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  ScrollController scrollController = ScrollController();
  bool showControls = false;
  LoadingHandler loadingHandler = LoadingHandler();

  VideoPlayerWidget? videoPlayerWidget;
  List<Uint8List>? progressThumbnails;
  Timer? hideControlsTimer;
  bool isFullScreen = false;
  String? failedToLoadReason;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  bool loadedCommentsOnce = false;
  bool isLoadingComments = true;
  bool isLoadingMoreComments = false;
  bool showCommentSection = false;
  bool showReplySection = false;
  int replyCommentIndex = -1;
  bool descriptionExpanded = false;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];

  // Fill with garbage for skeleton
  List<UniversalComment>? comments = List.generate(
    10,
    (index) => UniversalComment(
      videoID: "",
      author: "author",
      commentBody: List<String>.filled(5, "comment").join(),
      plugin: null,
      hidden: false,
    ),
  );
  UniversalVideoMetadata videoMetadata = UniversalVideoMetadata(
      videoID: 'none',
      m3u8Uris: {},
      title: List<String>.filled(10, 'title').join(), // long string
      plugin: null);

  Future<List<UniversalVideoPreview>?> videoSuggestions =
      Future.value(List.filled(
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
          )));

  @override
  void initState() {
    super.initState();

    scrollController.addListener((commentsScrollListener));

    Connectivity().checkConnectivity().then((value) {
      if (value.contains(ConnectivityResult.none)) {
        logger.e("No internet connection");
        setState(() {
          failedToLoadReason = "No internet connection";
        });
      }
    });

    widget.videoMetadata.whenComplete(() async {
      videoMetadata = await widget.videoMetadata;

      // Start loading video suggestions, but don't wait for them
      videoSuggestions = loadingHandler.getVideoSuggestions(
          videoMetadata.plugin!,
          videoMetadata.videoID,
          videoMetadata.rawHtml,
          null);

      setState(() {
        isLoadingMetadata = false;
      });

      // Update screen after progress thumbnails are loaded
      sharedStorage.getBool("show_progress_thumbnails").then((value) {
        if (value!) {
          videoMetadata.plugin!
              .getProgressThumbnails(
                  videoMetadata.videoID, videoMetadata.rawHtml)
              .then((value) {
            setState(() => progressThumbnails = value);
          });
        }
      });
    }).catchError((e) {
      logger.e("Error getting video metadata: $e");
      if (failedToLoadReason != "No internet connection") {
        setState(() => failedToLoadReason = e.toString());
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  void openComments() async {
    logger.d("Opening comment section");
    setState(() {
      showCommentSection = true;
    });
    if (!loadedCommentsOnce) {
      setState(() {
        isLoadingComments = true;
      });
      comments = await loadingHandler.getCommentResults(videoMetadata.plugin!,
          videoMetadata.videoID, videoMetadata.rawHtml, null);
      setState(() {
        isLoadingComments = false;
      });
      logger.d("Finished getting comments");
      loadedCommentsOnce = true;
    }

    if (comments?.isNotEmpty ?? false) {
      // Ensure the frame has been rendered before checking maxScrollExtent, as
      // it otherwise throws "ScrollController not attached to any scroll views"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // If list is too short user will be unable to scroll and load more
        // comments -> check beforehand and automatically load another page
        if (scrollController.position.maxScrollExtent == 0.0) {
          commentsScrollListener(forceLoad: true);
        }
      });
    }
  }

  void openCommentSettings() async {
    // Navigate to settings page of comments
    logger.i("Opening comment settings");
    await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CommentsScreen()));
    logger.i("Refreshing comments");
    await loadingHandler.clearVariables();
    loadedCommentsOnce = false;
    openComments();
  }

  void commentsScrollListener({forceLoad = false}) async {
    if (!isLoadingMoreComments &&
            scrollController.position.pixels >=
                0.95 * scrollController.position.maxScrollExtent ||
        forceLoad) {
      logger.i(forceLoad
          ? "Force loading additional results to make list scrollable"
          : "Loading additional results");
      setState(() {
        isLoadingMoreComments = true;
      });
      comments = await loadingHandler.getCommentResults(videoMetadata.plugin!,
          videoMetadata.videoID, videoMetadata.rawHtml, comments);
      logger.i("Finished getting more results");
      setState(() {
        isLoadingMoreComments = false;
      });
    }
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
    TextStyle mediumTextStyle = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(color: Theme.of(context).colorScheme.onSurface);
    return Scaffold(
        body: SafeArea(
            child: PopScope(
                // only allow pop if not in fullscreen
                canPop:
                    !isFullScreen && !showCommentSection && !showReplySection,
                onPopInvoked: (goingToPop) {
                  // immediately stop video if popping
                  if (goingToPop) {
                    // FIXME: Stop video immediately on pop
                    // controller.pause();
                  }
                  // restore upright orientation
                  if (isFullScreen) {
                    toggleFullScreen();
                    return;
                  }
                  if (showReplySection) {
                    setState(() {
                      showReplySection = false;
                    });
                    return;
                  }
                  if (showCommentSection) {
                    setState(() {
                      showCommentSection = false;
                    });
                  }
                },
                child: failedToLoadReason != null
                    ? Center(
                        child: Padding(
                            padding: EdgeInsets.only(
                                left: MediaQuery.of(context).size.width * 0.1,
                                right: MediaQuery.of(context).size.width * 0.1,
                                bottom:
                                    MediaQuery.of(context).size.height * 0.5),
                            child: Text(
                                "Couldn't load video: $failedToLoadReason",
                                style: const TextStyle(fontSize: 20),
                                textAlign: TextAlign.center)))
                    : Skeletonizer(
                        enabled: isLoadingMetadata,
                        child: Column(children: <Widget>[
                          SizedBox(
                              height: MediaQuery.of(context).orientation ==
                                      Orientation.landscape
                                  ? MediaQuery.of(context).size.height
                                  : MediaQuery.of(context).size.width * 9 / 16,
                              child: Skeleton.shade(
                                  child: isLoadingMetadata
                                      // to show a skeletonized box, display a container with a color
                                      // Does NOT work if the container has no color
                                      ? Container(color: Colors.black)
                                      : VideoPlayerWidget(
                                          videoMetadata: videoMetadata,
                                          progressThumbnails:
                                              progressThumbnails,
                                          toggleFullScreen: toggleFullScreen,
                                          isFullScreen: isFullScreen,
                                          updateFailedToLoadReason:
                                              (String reason) => setState(() =>
                                                  failedToLoadReason = reason),
                                        ))),
                          // only show the following widgets if not in fullscreen
                          if (!isFullScreen) ...[
                            Expanded(
                                child: Stack(children: [
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 10, right: 10, bottom: 10, top: 2),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        // make sure the text element takes up the whole available space
                                        SizedBox(
                                            width: double.infinity,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                    child: GestureDetector(
                                                        onLongPress: () {
                                                          Clipboard.setData(
                                                              ClipboardData(
                                                                  text: videoMetadata
                                                                      .title));
                                                          // TODO: Add vibration feedback for mobile
                                                          ToastMessageShower
                                                              .showToast(
                                                                  "Copied video title to clipboard",
                                                                  context);
                                                        },
                                                        child: Text(
                                                            videoMetadata.title,
                                                            style: const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines:
                                                                descriptionExpanded
                                                                    ? 10
                                                                    : 2))),
                                                IconButton(
                                                    icon: Icon(
                                                      descriptionExpanded
                                                          ? Icons
                                                              .keyboard_arrow_up
                                                          : Icons
                                                              .keyboard_arrow_down,
                                                      color: Colors.white,
                                                      size: 30.0,
                                                    ),
                                                    onPressed: () =>
                                                        setState(() {
                                                          descriptionExpanded =
                                                              !descriptionExpanded;
                                                        }))
                                              ],
                                            )),
                                        if (descriptionExpanded) ...[
                                          Text(videoMetadata.description ??
                                              "No description available"),
                                        ],
                                        const SizedBox(height: 20),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                Text(
                                                    isLoadingMetadata
                                                        ? "3000 "
                                                        : videoMetadata
                                                                    .viewsTotal ==
                                                                null
                                                            ? "-"
                                                            : "${convertNumberIntoHumanReadable(videoMetadata.viewsTotal!)} ",
                                                    maxLines: 1,
                                                    style: mediumTextStyle),
                                                Skeleton.shade(
                                                    child: Icon(
                                                        size: 16,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        Icons.remove_red_eye))
                                              ]),
                                              Row(children: [
                                                Skeleton.shade(
                                                    child: Icon(
                                                        size: 16,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        Icons.thumb_up)),
                                                const SizedBox(width: 5),
                                                Text(
                                                    isLoadingMetadata
                                                        ? "3000 | 300"
                                                        : "${videoMetadata.ratingsPositiveTotal == null ? "-" : convertNumberIntoHumanReadable(videoMetadata.ratingsPositiveTotal!)} "
                                                            "| ${videoMetadata.ratingsNegativeTotal == null ? "-" : convertNumberIntoHumanReadable(videoMetadata.ratingsNegativeTotal!)}",
                                                    maxLines: 1,
                                                    style: mediumTextStyle),
                                                const SizedBox(width: 5),
                                                Skeleton.shade(
                                                    child: Icon(
                                                        size: 16,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        Icons.thumb_down))
                                              ])
                                            ]),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                            width: double.infinity,
                                            child: Skeleton.shade(
                                                child: TextButton(
                                                    style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onPrimary,
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary),
                                                    onPressed: isLoadingMetadata
                                                        ? null
                                                        : () => openComments(),
                                                    child: Text("Comments")))),
                                        const SizedBox(height: 20),
                                        FutureBuilder<UniversalVideoMetadata>(
                                          future: widget.videoMetadata,
                                          builder: (context, snapshot) {
                                            // only build when data finished loading
                                            if (snapshot.data == null) {
                                              return const SizedBox();
                                            }
                                            return Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      "Related videos from ${videoMetadata.plugin!.prettyName}:",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium!),
                                                  const SizedBox(height: 10),
                                                  Expanded(
                                                      child: VideoList(
                                                          videoList:
                                                              videoSuggestions,
                                                          listType:
                                                              "suggestions",
                                                          noListPadding: true,
                                                          loadingHandler:
                                                              loadingHandler,
                                                          plugin: videoMetadata
                                                              .plugin,
                                                          videoID: videoMetadata
                                                              .videoID,
                                                          rawHtml: videoMetadata
                                                              .rawHtml))
                                                ]));
                                          },
                                        ),
                                      ])),
                              if (showCommentSection) ...[
                                Stack(children: [
                                  buildCommentSection(),
                                  if (showReplySection) ...[
                                    buildReplyCommentSection(replyCommentIndex)
                                  ]
                                ])
                              ],
                            ]))
                          ]
                        ]),
                      ))));
  }

  Widget buildCommentSection() {
    return Positioned.fill(
        child: Container(
            decoration: BoxDecoration(
              // While surfaceVariant is deprecated, the suggested replacement
              // surfaceContainerHighest is the same color as surface, which is
              // used to highlight the top level comment
              // TODO: Figure out if the bug is upstream or in dynamic_color and fix it
              color: Theme.of(context).colorScheme.surfaceVariant,
              // Set the background color of the container
              borderRadius: BorderRadius.circular(25), // Set the border radius
            ),
            // build as many widgets as there are in the list
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 10, top: 10, bottom: 5),
                  child: Row(children: [
                    Text(
                        "Comments ${isLoadingComments || isLoadingMoreComments ? "" : "(${comments?.length ?? 0})"}",
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => openCommentSettings(),
                        icon: Icon(Icons.filter_alt,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    IconButton(
                        onPressed: () =>
                            setState(() => showCommentSection = false),
                        icon: Icon(Icons.close,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant))
                  ])),
              Divider(
                  height: 0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  thickness: 1),
              Expanded(
                  child: Skeletonizer(
                      enabled: isLoadingComments,
                      child: comments?.isEmpty ?? true
                          ? Center(
                              child: Text(
                                  comments == null
                                      ? "Failed to load comments"
                                      : "No comments",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall!
                                      .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                  textAlign: TextAlign.center),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount: comments!.length +
                                  (isLoadingMoreComments ? 1 : 0),
                              itemBuilder: (context, index) {
                                return index == comments!.length
                                    ? Center(
                                        child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: CircularProgressIndicator(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)))
                                    : Padding(
                                        // only insert some space at the top for the first ListTile
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        child: buildComment(comments!, index));
                              },
                            )))
            ])));
  }

  // Use separate widget for the reply comment section
  // If the main section was to be used for reply comments too, this would
  // necessitate keeping track of the scroll position
  Widget buildReplyCommentSection(int replyCommentIndex) {
    return Positioned.fill(
        child: Container(
            decoration: BoxDecoration(
              // While surfaceVariant is deprecated, the suggested replacement
              // surfaceContainerHighest is the same color as surface, which is
              // used to highlight the top level comment
              // TODO: Figure out if the bug is upstream or in dynamic_color and fix it
              color: Theme.of(context).colorScheme.surfaceVariant,
              // Set the background color of the container
              borderRadius: BorderRadius.circular(25), // Set the border radius
            ),
            // build as many widgets as there are in the list
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.only(
                      right: 10, left: 5, top: 10, bottom: 5),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                            onPressed: () =>
                                setState(() => showReplySection = false),
                            icon: Icon(Icons.arrow_back,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        Text(
                            "Replies (${comments![replyCommentIndex].replyComments?.length ?? "No reply comments?"})",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w500)),
                        const Spacer(),
                        IconButton(
                            onPressed: () => setState(() {
                                  showReplySection = false;
                                  showCommentSection = false;
                                }),
                            icon: Icon(Icons.close,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant))
                      ])),
              Divider(
                  height: 0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  thickness: 1),
              Expanded(
                  child: comments![replyCommentIndex].replyComments?.isEmpty ??
                          true
                      ? Center(
                          child: Text("No reply comments? Report this",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                              textAlign: TextAlign.center),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount: comments![replyCommentIndex]
                                  .replyComments!
                                  .length +
                              1,
                          itemBuilder: (context, index) {
                            return Container(
                                color: index == 0
                                    ? Theme.of(context).colorScheme.surface
                                    : Colors.transparent,
                                child: Padding(
                                    // only insert some space at the top for the first ListTile
                                    padding: EdgeInsets.only(
                                        top: 10, bottom: index != 0 ? 10 : 0),
                                    child: index == 0
                                        ? buildComment(
                                            comments!, replyCommentIndex)
                                        : buildComment(
                                            comments![replyCommentIndex]
                                                .replyComments!,
                                            index - 1)));
                          },
                        ))
            ])));
  }

  Widget buildComment(List<UniversalComment> commentsList, int index) {
    return ListTile(
      dense: true,
      leading: Skeleton.shade(
        child: ClipOval(
          child: Container(
            width: 40,
            height: 40,
            color: Theme.of(context).colorScheme.tertiary,
            child: Image.network(
              commentsList[index].profilePicture ?? "",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onTertiary,
              ),
            ),
          ),
        ),
      ),
      title: Text(
          "${commentsList[index].hidden ? "(hidden comment) " : ""}${commentsList[index].author} • ${getTimeDeltaInHumanReadable(commentsList[index].commentDate)} ago",
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: commentsList[index].hidden
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              )),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          commentsList[index].commentBody,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 5),
        Row(children: [
          Row(children: [
            Skeleton.shade(
                child: Icon(
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    Icons.thumb_up)),
            const SizedBox(width: 5),
            Text(
                isLoadingComments
                    ? "3000 | 300"
                    : commentsList[index].ratingsPositiveTotal != null &&
                            commentsList[index].ratingsNegativeTotal != null
                        ? "${convertNumberIntoHumanReadable(commentsList[index].ratingsPositiveTotal!)} "
                            "| ${convertNumberIntoHumanReadable(commentsList[index].ratingsNegativeTotal!)}"
                        : "${commentsList[index].ratingsTotal}",
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 5),
            Skeleton.shade(
                child: Icon(
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    Icons.thumb_down))
          ]),
          if (commentsList[index].replyComments?.isNotEmpty ?? false) ...[
            TextButton(
                child: Row(children: [
                  Skeleton.shade(
                      child: Icon(
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          Icons.comment)),
                  const SizedBox(width: 5),
                  Text(
                      isLoadingComments
                          ? "10"
                          : convertNumberIntoHumanReadable(
                              commentsList[index].replyComments!.length),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
                onPressed: () => setState(() {
                      replyCommentIndex = index;
                      showReplySection = true;
                    })),
          ],
        ])
      ]),
      isThreeLine: true,
    );
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
