import 'dart:async';
import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '/services/database_manager.dart';
import '/services/loading_handler.dart';
import '/ui/screens/bug_report.dart';
import '/ui/screens/scraping_report.dart';
import '/ui/screens/settings/settings_comments.dart';
import '/ui/screens/video_list.dart';
import '/ui/screens/video_screen/player_widget.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/utils/convert.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

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

  List<Uint8List>? progressThumbnails;
  Timer? hideControlsTimer;
  bool isFullScreen = false;
  String? failedToLoadReason;
  String? detailedFailReason;
  bool firstPlay = true;
  bool isLoadingMetadata = true;
  bool loadedCommentsOnce = false;
  bool isLoadingComments = true;
  bool isLoadingMoreComments = false;
  int commentsAmount = 0;
  bool showCommentSection = false;
  bool showReplySection = false;
  int replyCommentIndex = -1;
  bool descriptionExpanded = false;
  int selectedResolution = 0;
  List<int> sortedResolutions = [];

  // Fill with garbage for skeleton
  List<UniversalComment>? comments = List.generate(
    10,
    (index) => UniversalComment.skeleton(),
  );
  UniversalVideoMetadata videoMetadata = UniversalVideoMetadata.skeleton();

  Future<List<UniversalVideoPreview>?> videoSuggestions =
      Future.value(List.filled(12, UniversalVideoPreview.skeleton()));

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
          videoMetadata.plugin!, videoMetadata.iD, videoMetadata.rawHtml, null);

      setState(() {
        isLoadingMetadata = false;
      });

      // Update screen after progress thumbnails are loaded
      sharedStorage.getBool("media_show_progress_thumbnails").then((value) {
        if (value!) {
          videoMetadata.plugin!
              .getProgressThumbnails(videoMetadata.iD, videoMetadata.rawHtml)
              .then((value) {
            setState(() => progressThumbnails = value);
          });
        }
      });
    }).catchError((e, stacktrace) {
      logger.e("Error getting video metadata: $e\n$stacktrace");
      if (failedToLoadReason != "No internet connection") {
        setState(() {
          failedToLoadReason = e.toString();
          detailedFailReason = stacktrace.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    videoMetadata.plugin?.cancelGetVideoMetadata();
    videoMetadata.plugin?.cancelGetProgressThumbnails();
    videoMetadata.plugin?.cancelGetVideoSuggestions();
    videoMetadata.plugin?.cancelGetComments();
    super.dispose();
  }

  void openComments() async {
    logger.d("Opening comment section");
    setState(() => showCommentSection = true);
    if (!loadedCommentsOnce) {
      setState(() => isLoadingComments = true);
      comments = await loadingHandler.getCommentResults(
          videoMetadata.plugin!, videoMetadata.iD, videoMetadata.rawHtml, null);
      commentsAmount = comments?.length ?? 0;
      setState(() => isLoadingComments = false);
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
    loadingHandler.commentsPageCounter = 0;
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
      setState(() => isLoadingMoreComments = true);
      comments = await loadingHandler.getCommentResults(videoMetadata.plugin!,
          videoMetadata.iD, videoMetadata.rawHtml, comments);
      commentsAmount = comments?.length ?? 0;
      logger.i("Finished getting more results");
      // This also updates the scraping report button
      setState(() => isLoadingMoreComments = false);
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

  Future<void> openExternalLink(Uri link) async {
    try {
      launchUrl(link);
    } catch (e, stacktrace) {
      logger.e("Failed to open video in browser: $e\n$stacktrace");
      showToast("Failed to open video in browser: $e", context);
    }
  }

  Future<void> showExternalLinkWarning(Uri link) async {
    bool checkBoxValue = false;
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) =>
                  ThemedDialog(
                      title: "Privacy warning",
                      primaryText: "Continue",
                      onPrimary: () async {
                        if (checkBoxValue) {
                          await sharedStorage.setBool(
                              "privacy_show_external_link_warning", false);
                        }
                        openExternalLink(link);
                        // close popup
                        Navigator.pop(context);
                      },
                      secondaryText: "Cancel",
                      onSecondary: Navigator.of(context).pop,
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            "This will open the link below in your default browser. Your"
                            " default browser might not have the same privacy settings "
                            "as Hedon Haven. Are you sure you want to continue?",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Text(link.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall))),
                        const SizedBox(height: 5),
                        Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Spacer(),
                              Text(
                                "Don't show this again",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Checkbox(
                                  visualDensity: VisualDensity.compact,
                                  value: checkBoxValue,
                                  onChanged: (value) =>
                                      setState(() => checkBoxValue = value!))
                            ]),
                      ])));
        });
  }

  Future<List<UniversalVideoPreview>?> loadMoreResults() async {
    var results = loadingHandler.getVideoSuggestions(videoMetadata.plugin!,
        videoMetadata.iD, videoMetadata.rawHtml, await videoSuggestions);
    // Update warnings/errors button
    setState(() {});
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: PopScope(
                // only allow pop if not in fullscreen
                canPop:
                    !isFullScreen && !showCommentSection && !showReplySection,
                onPopInvoked: (goingToPop) {
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
                                top: MediaQuery.of(context).size.height * 0.1),
                            child: Column(children: [
                              Text(
                                  failedToLoadReason == "No internet connection"
                                      ? "No internet connection"
                                      : "Failed to load video",
                                  style: const TextStyle(fontSize: 20),
                                  textAlign: TextAlign.center),
                              if (failedToLoadReason != null &&
                                  failedToLoadReason !=
                                      "No internet connection") ...[
                                ElevatedButton(
                                    style: TextButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    child: Text("Open scraping report",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary)),
                                    onPressed: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ScrapingReportScreen(
                                                    singleProviderMap: {
                                                  "Critical": [
                                                    "$failedToLoadReason"
                                                        "\n$detailedFailReason"
                                                  ]
                                                },
                                                    singleProviderCodeName:
                                                        videoMetadata
                                                            .plugin?.codeName),
                                          ));
                                    })
                              ]
                            ])))
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
                                                          showToast(
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
                                        buildMetadataSection(),
                                        if (descriptionExpanded) ...[
                                          const SizedBox(height: 10),
                                          Text(videoMetadata.description ??
                                              "No description available"),
                                        ],
                                        const SizedBox(height: 20),
                                        buildActionButtonsRow(),
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
                                        FutureBuilder<UniversalVideoMetadata?>(
                                          future: widget.videoMetadata,
                                          builder: (context, _) {
                                            return Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Row(children: [
                                                    Text(
                                                        "Related videos from ${videoMetadata.plugin?.prettyName ?? ""}:",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium!),
                                                    Spacer(),
                                                    if (loadingHandler
                                                            .videoSuggestionsIssues
                                                            .isNotEmpty &&
                                                        !isLoadingMetadata) ...[
                                                      IconButton(
                                                          icon: Icon(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .error,
                                                              Icons
                                                                  .error_outline),
                                                          onPressed: () =>
                                                              Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder: (context) =>
                                                                          ScrapingReportScreen(
                                                                            singleProviderMap:
                                                                                loadingHandler.videoSuggestionsIssues,
                                                                            singleProviderCodeName:
                                                                                videoMetadata.plugin?.codeName,
                                                                          ))).whenComplete(
                                                                  () => setState(
                                                                      () {})))
                                                    ]
                                                  ]),
                                                  const SizedBox(height: 10),
                                                  Expanded(
                                                      child: VideoList(
                                                    videoList: videoSuggestions,
                                                    listType: "suggestions",
                                                    noListPadding: true,
                                                    loadingHandler:
                                                        loadingHandler,
                                                    plugin:
                                                        videoMetadata.plugin,
                                                    loadMoreResults:
                                                        loadMoreResults,
                                                  ))
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

  Widget buildMetadataSection() {
    TextStyle mediumTextStyle = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(color: Theme.of(context).colorScheme.onSurface);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Text(
            isLoadingMetadata
                ? "3000 "
                : videoMetadata.viewsTotal == null
                    ? "-"
                    : descriptionExpanded
                        ? "${formatWithDots(videoMetadata.viewsTotal!)} "
                        : "${convertNumberIntoHumanReadable(videoMetadata.viewsTotal!)} ",
            maxLines: 1,
            style: mediumTextStyle),
        Skeleton.shade(
            child: Icon(
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
                Icons.remove_red_eye))
      ]),
      Row(children: [
        Text(
            isLoadingMetadata
                ? "unknown time ago"
                : videoMetadata.uploadDate == null
                    ? "-"
                    : "${getTimeDeltaInHumanReadable(videoMetadata.uploadDate!)} ago ",
            maxLines: 1,
            style: mediumTextStyle),
        Skeleton.shade(
            child: Icon(
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
                Icons.upload))
      ]),
      Row(children: [
        Skeleton.shade(
            child: Icon(
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
                Icons.thumb_up)),
        const SizedBox(width: 5),
        Text(
            isLoadingMetadata
                ? "3000 | 300"
                : "${videoMetadata.ratingsPositiveTotal == null ? "-" : descriptionExpanded ? "${videoMetadata.ratingsPositiveTotal!}" : convertNumberIntoHumanReadable(videoMetadata.ratingsPositiveTotal!)} "
                    "| ${videoMetadata.ratingsNegativeTotal == null ? "-" : descriptionExpanded ? "${videoMetadata.ratingsNegativeTotal!}" : convertNumberIntoHumanReadable(videoMetadata.ratingsNegativeTotal!)}",
            maxLines: 1,
            style: mediumTextStyle),
        const SizedBox(width: 5),
        Skeleton.shade(
            child: Icon(
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
                Icons.thumb_down))
      ])
    ]);
  }

  Widget buildActionButtonsRow() {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 10,
            children: [
              SizedBox(
                  child: FutureBuilder<bool?>(
                future: isInFavorites(videoMetadata.iD),
                builder: (context, snapshot) {
                  return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary),
                      child: Row(children: [
                        Icon(
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                            snapshot.data ?? false
                                ? Icons.favorite
                                : Icons.favorite_border),
                        Text(snapshot.data ?? false
                            ? " Remove from favorites"
                            : " Add to favorites")
                      ]),
                      onPressed: () async {
                        if (snapshot.data == null) return;
                        if (snapshot.data!) {
                          await removeFromFavorites(
                              videoMetadata.universalVideoPreview);
                        } else {
                          await addToFavorites(
                              videoMetadata.universalVideoPreview);
                        }
                        setState(() {});
                      });
                },
              )),
              SizedBox(
                  child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary),
                child: Row(children: [
                  Icon(
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                      Icons.share),
                  Text(" Share")
                ]),
                onPressed: () {
                  // Windows and linux don't have share implementations
                  // -> Copy to clipboard and show warning instead
                  if (Platform.isWindows || Platform.isLinux) {
                    Clipboard.setData(ClipboardData(
                        text: videoMetadata.plugin!
                            .getVideoUriFromID(videoMetadata.iD)
                            .toString()));
                    showToast(
                        "Share not available on "
                        "${Platform.isWindows ? "Windows" : "Linux"}. "
                        "Copied link to clipboard instead",
                        context);
                  }
                  Share.shareUri(videoMetadata.plugin!
                      .getVideoUriFromID(videoMetadata.iD)!);
                },
              )),
              SizedBox(
                  child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary),
                child: Row(children: [
                  Icon(
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                      Icons.open_in_new),
                  Text(" Open in browser")
                ]),
                onPressed: () async {
                  if ((await sharedStorage
                      .getBool("privacy_show_external_link_warning"))!) {
                    showExternalLinkWarning(videoMetadata.plugin!
                        .getVideoUriFromID(videoMetadata.iD)!);
                  } else {
                    openExternalLink(videoMetadata.plugin!
                        .getVideoUriFromID(videoMetadata.iD)!);
                  }
                },
              )),
              SizedBox(
                  child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary),
                child: Row(children: [
                  Icon(
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                      Icons.bug_report),
                  Text(" Report bug")
                ]),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BugReportScreen(
                              debugObject: [videoMetadata.convertToMap()])));
                },
              ))
            ]));
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
                        "Comments (${isLoadingComments ? "?" : commentsAmount}) ",
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (loadingHandler.commentsIssues.isNotEmpty &&
                        !isLoadingComments &&
                        !isLoadingMoreComments) ...[
                      IconButton(
                        icon: Icon(
                            color: Theme.of(context).colorScheme.error,
                            Icons.error_outline),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ScrapingReportScreen(
                                      singleProviderMap:
                                          loadingHandler.commentsIssues,
                                      singleProviderCodeName:
                                          videoMetadata.plugin?.codeName,
                                    ))).whenComplete(() => setState(() {})),
                      )
                    ],
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
                          ? Column(children: [
                              Padding(
                                  padding: const EdgeInsets.only(
                                      top: 50, bottom: 10),
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
                                      textAlign: TextAlign.center)),
                              if (comments == null) ...[
                                ElevatedButton(
                                    style: TextButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    child: Text("Open scraping report",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary)),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                ScrapingReportScreen(
                                                    singleProviderMap:
                                                        loadingHandler
                                                            .commentsIssues,
                                                    singleProviderCodeName:
                                                        videoMetadata.plugin
                                                            ?.codeName))))
                              ]
                            ])
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
    return GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text("Create bug report"),
                    onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => BugReportScreen(
                                        debugObject: [
                                          commentsList[index].convertToMap()
                                        ])))
                        .then((value) => Navigator.of(context).pop()));
              });
        },
        child: ListTile(
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
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const SizedBox(width: 15),
                TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(0),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(children: [
                      Skeleton.shade(
                          child: Icon(
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              Icons.comment)),
                      const SizedBox(width: 5),
                      Text(
                          isLoadingComments
                              ? "10"
                              : convertNumberIntoHumanReadable(
                                  commentsList[index].replyComments!.length),
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ]),
                    onPressed: () => setState(() {
                          replyCommentIndex = index;
                          showReplySection = true;
                        })),
              ],
            ])
          ]),
          isThreeLine: true,
        ));
  }
}
