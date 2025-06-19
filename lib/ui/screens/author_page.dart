import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '/services/loading_handler.dart';
import '/ui/screens/bug_report.dart';
import '/ui/screens/scraping_report.dart';
import '/ui/screens/video_list.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
import '/ui/widgets/external_link_warning.dart';
import '/utils/convert.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

class AuthorPageScreen extends StatefulWidget {
  Future<UniversalAuthorPage?> authorPage;

  AuthorPageScreen({super.key, required this.authorPage});

  @override
  State<AuthorPageScreen> createState() => _AuthorPageScreenState();
}

class _AuthorPageScreenState extends State<AuthorPageScreen> {
  LoadingHandler loadingHandler = LoadingHandler();
  Future<List<UniversalVideoPreview>?> authorVideos =
      Future.value(List.filled(12, UniversalVideoPreview.skeleton()));

  bool isLoadingResults = true;
  bool isInternetConnected = true;
  String? failedToLoadReason;
  String? detailedFailReason;

  UniversalAuthorPage? authorPage = UniversalAuthorPage.skeleton();

  @override
  void initState() {
    super.initState();

    Connectivity().checkConnectivity().then((value) {
      if (value.contains(ConnectivityResult.none)) {
        logger.e("No internet connection");
        setState(() {
          failedToLoadReason = "No internet connection";
        });
      }
    });

    widget.authorPage.whenComplete(() async {
      setState(() => isLoadingResults = true);
      authorPage = await widget.authorPage;
      // Start loading author videos but don't wait for them
      try {
        authorVideos =
            loadingHandler.getAuthorVideos(authorPage!.plugin!, authorPage!.iD);
      } catch (e, stacktrace) {
        logger.e("Error loading author videos: $e\n$stacktrace");
        loadingHandler.authorVideosIssues ==
            {
              "Critical": ["Error calling getAuthorVideos: $e\n$stacktrace"]
            };
        authorVideos = Future.value(null);
      }
      // If Connectivity contains ConnectivityResult.none -> no internet connection -> revert results
      isInternetConnected = !(await (Connectivity().checkConnectivity()))
          .contains(ConnectivityResult.none);
      logger.d("Internet connected: $isInternetConnected");
      // Make sure context is still mounted
      if (mounted) setState(() => isLoadingResults = false);
    }).catchError((e, stacktrace) {
      logger.e("Error getting author page: $e\n$stacktrace");
      if (failedToLoadReason != "No internet connection") {
        setState(() {
          failedToLoadReason = e.toString();
          detailedFailReason = stacktrace.toString();
        });
      }
    });
  }

  void buildLinksDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "External links",
            primaryText: "Close",
            onPrimary: () => Navigator.pop(context),
            content: SingleChildScrollView(
              child: Column(
                children: authorPage!.externalLinks!.entries
                    .map((entry) => ListTile(
                        title: Text(entry.key),
                        subtitle: Text(entry.value.toString()),
                        onTap: () => openExternalLinkWithWarningDialog(
                            context, entry.value)))
                    .toList(),
              ),
            )));
  }

  void openBannerInFullscreen() {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "Banner image",
            primaryText: "Close",
            onPrimary: () => Navigator.pop(context),
            content: SingleChildScrollView(
                child: Image.network(authorPage?.banner ?? "Banner url is null",
                    errorBuilder: (context, error, stackTrace) {
              if (!error.toString().contains("mockBanner")) {
                logger.e("Failed to load network banner: $error\n$stackTrace");
              }
              return Icon(Icons.error,
                  color: Theme.of(context).colorScheme.error);
            }, fit: BoxFit.contain))));
  }

  void buildAboutDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) => ThemedDialog(
            title: "About author",
            primaryText: "Close",
            onPrimary: () => Navigator.pop(context),
            content:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Description:",
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 5),
              Expanded(
                  child: TextFormField(
                      initialValue: authorPage?.description ?? "No description",
                      readOnly: true,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          hoverColor: Theme.of(context).colorScheme.surface))),
              SizedBox(height: 20),
              Text("Advanced description:",
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 5),
              Expanded(
                  child: TextFormField(
                      initialValue: (() {
                        if (authorPage?.advancedDescription?.isEmpty ?? true) {
                          return "No advanced description";
                        }
                        return authorPage!.advancedDescription!.entries
                            .map((e) => "${e.key}: ${e.value}")
                            .join("\n")
                            .trim();
                      })(),
                      readOnly: true,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          hoverColor: Theme.of(context)
                              .colorScheme
                              .surface // disables hover effect
                          )))
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            iconTheme:
                IconThemeData(color: Theme.of(context).colorScheme.primary),
            actions: [
              if (authorPage?.scrapeFailMessage != null &&
                  !isLoadingResults) ...[
                IconButton(
                    icon: Icon(
                        color: Theme.of(context).colorScheme.error,
                        Icons.error_outline),
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ScrapingReportScreen(
                                    singleMessage:
                                        authorPage!.scrapeFailMessage,
                                    singleDebugObject:
                                        authorPage!.toMap(),
                                  )));
                      setState(() {});
                    })
              ]
            ]),
        body: SafeArea(
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
                                  : "Failed to load author page",
                              style: const TextStyle(fontSize: 20),
                              textAlign: TextAlign.center),
                          if (failedToLoadReason != null &&
                              failedToLoadReason !=
                                  "No internet connection") ...[
                            ElevatedButton(
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary),
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
                                                "Failed to load ${authorPage?.iD ?? "unknown author"}: $failedToLoadReason"
                                                    "\n$detailedFailReason"
                                              ]
                                            },
                                                singleDebugObject:
                                                    authorPage?.toMap()),
                                      ));
                                })
                          ]
                        ])))
                : Skeletonizer(
                    enabled: isLoadingResults,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 10,
                            children: [
                              if (authorPage?.banner != null) ...[
                                Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                            onTap: () =>
                                                openBannerInFullscreen(),
                                            child: Image.network(
                                                authorPage?.banner ??
                                                    "Banner url is null",
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                              if (!error
                                                  .toString()
                                                  .contains("mockBanner")) {
                                                logger.e(
                                                    "Failed to load network banner: $error\n$stackTrace");
                                              }
                                              return Icon(
                                                Icons.error,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                              );
                                            }, fit: BoxFit.cover))))
                              ],
                              buildAuthorDetails(),
                              SizedBox(),
                              buildActionButtonsRow(),
                              Text(
                                  "Videos from ${authorPage?.name} on ${authorPage?.plugin?.prettyName}"
                                  "${authorPage?.videosTotal != null ? " (total: ${authorPage?.videosTotal})" : ""}: "),
                              Expanded(
                                  child: VideoList(
                                      videoList: authorVideos,
                                      loadMoreResults: () async =>
                                          loadingHandler.getAuthorVideos(
                                              authorPage!.plugin!,
                                              authorPage!.iD,
                                              await authorVideos),
                                      cancelLoadingHandler:
                                          loadingHandler.cancelGetAuthorVideos,
                                      noResultsMessage:
                                          "This author has no videos on this platform",
                                      noResultsErrorMessage:
                                          "Failed to load videos from this author",
                                      showScrapingReportButton: true,
                                      scrapingReportMap:
                                          loadingHandler.authorVideosIssues,
                                      ignoreInternetError: false,
                                      noListPadding: true,
                                      hideAuthors: true,
                                      singleProviderDebugObject:
                                          authorPage?.toMap()))
                            ])))));
  }

  Widget buildAuthorDetails() {
    return Row(children: [
      Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            // FIXME: skeletonizer showing the color
            color: Theme.of(context).colorScheme.tertiary,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(authorPage?.thumbnail ?? "Thumbnail url is null",
              errorBuilder: (context, error, stackTrace) {
            if (!error.toString().contains("mockThumbnail")) {
              logger.e(
                  "Failed to load network author thumbnail: $error\n$stackTrace");
            }
            return Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onTertiary,
            );
          }, fit: BoxFit.cover)),
      SizedBox(width: 20),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authorPage!.name,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            SizedBox(height: 10),
                            Text(
                                "Subscribers: ${convertNumberIntoHumanReadable(authorPage?.subscribers ?? 0)}",
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                "Views: ${convertNumberIntoHumanReadable(authorPage?.viewsTotal ?? 0)}",
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                "Rank on ${authorPage?.plugin?.prettyName}:"
                                " ${authorPage?.rank ?? "-"}",
                                style: Theme.of(context).textTheme.titleMedium),
                          ])))
            ]),
            SizedBox(height: 10),
            TextButton(
                style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)))),
                child: Row(children: [
                  Expanded(
                    flex: 95,
                    child: Text(
                      authorPage?.description ?? "No description",
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                  SizedBox(width: 20),
                  Icon(Icons.open_in_full)
                ]),
                onPressed: () => buildAboutDialog())
          ]))
    ]);
  }

  Widget buildActionButtonsRow() {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 10,
            children: [
              FutureBuilder<bool?>(
                  // TODO: Add call to check subscription here
                  future: Future.value(false), // subscribed
                  builder: (context, snapshot) {
                    return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary),
                        onPressed: isLoadingResults
                            ? null
                            : () => showToast("Not yet implemented", context),
                        child: Row(children: [
                          Icon(
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimary,
                              snapshot.data ?? false
                                  ? Icons.notification_add
                                  : Icons.notifications_off_outlined),
                          Text(snapshot.data ?? false
                              ? " Unsubscribe"
                              : " Subscribe")
                        ]));
                  }),
              if (authorPage?.externalLinks?.isNotEmpty ?? false) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: isLoadingResults ? null : () => buildLinksDialog(),
                  child: Row(children: [
                    Icon(
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                        Icons.link),
                    Text("External links")
                  ]),
                )
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    backgroundColor: Theme.of(context).colorScheme.secondary),
                onPressed: isLoadingResults
                    ? null
                    : () async {
                        // Windows and linux don't have share implementations
                        // -> Copy to clipboard and show warning instead
                        if (Platform.isWindows || Platform.isLinux) {
                          Clipboard.setData(ClipboardData(
                              text: (await authorPage!.plugin!
                                      .getAuthorUriFromID(authorPage!.iD))
                                  .toString()));
                          showToast(
                              "Share not available on "
                              "${Platform.isWindows ? "Windows" : "Linux"}. "
                              "Copied link to clipboard instead",
                              context);
                        }
                        SharePlus.instance.share(ShareParams(
                            uri: await authorPage!.plugin!
                                .getAuthorUriFromID(authorPage!.iD)));
                      },
                child: Row(children: [
                  Icon(
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondary,
                      Icons.share),
                  Text(" Share")
                ]),
              ),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      backgroundColor: Theme.of(context).colorScheme.secondary),
                  onPressed: isLoadingResults
                      ? null
                      : () async => openExternalLinkWithWarningDialog(
                          context,
                          (await authorPage!.plugin!
                              .getAuthorUriFromID(authorPage!.iD))!),
                  child: Row(children: [
                    Icon(
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondary,
                        Icons.open_in_new),
                    Text(" Open in browser")
                  ])),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      backgroundColor: Theme.of(context).colorScheme.secondary),
                  onPressed: isLoadingResults
                      ? null
                      : () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BugReportScreen(
                                          debugObject: [
                                            authorPage!.toMap()
                                          ])));
                        },
                  child: Row(children: [
                    Icon(
                        size: 20,
                        color: Theme.of(context).colorScheme.onSecondary,
                        Icons.bug_report),
                    Text(" Report bug")
                  ]))
            ]));
  }
}
