import 'package:flutter/material.dart';

import '/backend/managers/loading_handler.dart';
import '/backend/universal_formats.dart';
import '/ui/screens/search.dart';
import '/ui/screens/video_list.dart';
import 'filters/filters.dart';

class ResultsScreen extends StatefulWidget {
  Future<List<UniversalSearchResult>> videoResults;
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
                        IconButton(
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (context) => FilterScreen(
                                        previousSearch: widget.searchRequest)))
                                .then((value) {
                              setState(() {
                                widget.videoResults = widget.loadingHandler
                                    .getSearchResults(widget.searchRequest);
                                // Force rebuild of VideoList by changing the key and forcing flutter to create a new VideoList
                                videoListKey = UniqueKey();
                              });
                            });
                          },
                          icon: const Icon(Icons.filter_alt),
                        )
                      ]))),
            ),
          ),
          body: VideoList(
            videoResults: widget.videoResults,
            listType: "results",
            loadingHandler: widget.loadingHandler,
            searchRequest: widget.searchRequest,
          ),
        ));
  }
}
