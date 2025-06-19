import 'package:flutter/material.dart';

import '/services/loading_handler.dart';
import '/services/plugin_manager.dart';
import '/ui/screens/scraping_report.dart';
import '/ui/screens/search.dart';
import '/ui/screens/video_list.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';
import 'filters/filters.dart';

class ResultsScreen extends StatefulWidget {
  Future<List<UniversalVideoPreview>?> videoResults;
  final LoadingHandler loadingHandler;
  UniversalSearchRequest searchRequest;

  ResultsScreen(
      {super.key,
      required this.videoResults,
      required this.searchRequest,
      required this.loadingHandler});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Key videoListKey = UniqueKey();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.videoResults.whenComplete(() {
      logger.d("ResultsIssues Map: ${widget.loadingHandler.resultsIssues}");
      // Update the scraping report button
      setState(() => isLoading = false);
    });
  }

  Future<List<UniversalVideoPreview>?> loadMoreResults() async {
    setState(() => isLoading = true);
    var results = widget.loadingHandler
        .getSearchResults(widget.searchRequest, await widget.videoResults);
    // Updates the scraping report button
    setState(() => isLoading = false);
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (goingToPop) {
          // Go back to home screen and clear navigation stack
          Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
        },
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: AppBar().preferredSize,
            child: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.only(
                      right: 8, left: 15, bottom: 6, top: 6),
                  child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              previousSearch: widget.searchRequest,
                            ),
                          )),
                      child: Row(children: [
                        Expanded(
                            child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: AppBar(
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                // Go back to home screen
                                Navigator.pushNamedAndRemoveUntil(
                                    context, "/", (route) => false);
                              },
                            ),
                            titleSpacing: 0.0,
                            title: Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: Text(widget.searchRequest.searchString,
                                    overflow: TextOverflow.clip,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ))),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(25),
                                    right: Radius.circular(25))),
                            elevation: 8,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                          ),
                        )),
                        if (widget.loadingHandler.resultsIssues.isNotEmpty &&
                            !isLoading) ...[
                          IconButton(
                              icon: Icon(
                                  color: Theme.of(context).colorScheme.error,
                                  Icons.error_outline),
                              onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              ScrapingReportScreen(
                                                  multiProviderMap: widget
                                                      .loadingHandler
                                                      .resultsIssues)))
                                  .whenComplete(() => setState(() {})))
                        ],
                        IconButton(
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (context) => FilterScreen(
                                        previousSearch: widget.searchRequest)))
                                .then((value) {
                              widget.videoResults = widget.loadingHandler
                                  .getSearchResults(widget.searchRequest);
                              // Force rebuild of VideoList by changing the key and forcing flutter to create a new VideoList
                              setState(() => videoListKey = UniqueKey());
                            });
                          },
                          icon: const Icon(Icons.filter_alt),
                        )
                      ]))),
            ),
          ),
          body: VideoList(
              // This key is needed to completely rebuild the VideoList widget
              key: videoListKey,
              videoList: widget.videoResults,
              searchRequest: widget.searchRequest,
              reloadInitialResults: () =>
                  widget.loadingHandler.getSearchResults(widget.searchRequest),
              loadMoreResults: loadMoreResults,
              cancelLoadingHandler:
                  widget.loadingHandler.cancelGetSearchResults,
              noResultsMessage: "No results found",
              noResultsErrorMessage: "Error loading results",
              showScrapingReportButton: true,
              scrapingReportMap: widget.loadingHandler.resultsIssues,
              ignoreInternetError: false,
              noPluginsEnabled: PluginManager.enabledResultsProviders.isEmpty,
              noPluginsMessage:
                  "No result providers enabled. Enable at least one plugin's result provider setting"),
        ));
  }
}
