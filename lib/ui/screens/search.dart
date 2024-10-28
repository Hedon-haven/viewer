import 'package:flutter/material.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/loading_handler.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/filters/filters.dart';
import '/ui/screens/results.dart';
import '/ui/toast_notification.dart';

class SearchScreen extends StatefulWidget {
  UniversalSearchRequest previousSearch;

  SearchScreen({super.key, required this.previousSearch});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool searchHistoryEnabled = false;
  List<UniversalSearchRequest> searchSuggestions = [];
  List<UniversalSearchRequest> historySuggestions = [];

  @override
  void initState() {
    super.initState();
    // apply old filter settings
    _controller.text = widget.previousSearch.searchString;
    // Set search suggestions to search history and update to show them
    DatabaseManager.getSearchHistory()
        .then((value) => setState(() => historySuggestions = value));
    // Check if search history is disabled
    searchHistoryEnabled = sharedStorage.getBool("enable_search_history")!;
    logger.d("Search history enabled: $searchHistoryEnabled");

    // Request focus
    // The future is to avoid calling this before the widget is done initializing
    Future.delayed(Duration.zero, () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void startSearchQuery(UniversalSearchRequest query) async {
    LoadingHandler searchHandler = LoadingHandler();
    widget.previousSearch.searchString = query.searchString;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          videoResults: searchHandler.getSearchResults(widget.previousSearch),
          searchRequest: widget.previousSearch,
          loadingHandler: searchHandler,
        ),
      ),
    )
        .then((value) {
      _focusNode.requestFocus();
    }); // Bring up keyboard on return from results screen
  }

  @override
  Widget build(BuildContext context) {
    List<UniversalSearchRequest> displayedSuggestions =
        searchSuggestions.isNotEmpty ? searchSuggestions : historySuggestions;
    logger.d("Search suggestions not empty?: ${searchSuggestions.isNotEmpty}");
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          shape: Border(
              bottom:
                  BorderSide(color: Theme.of(context).colorScheme.secondary)),
          titleSpacing: 0.0,
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (searchString) async {
                    try {
                      searchSuggestions = await LoadingHandler()
                          .getSearchSuggestions(searchString);
                      setState(() {});
                    } catch (e) {
                      logger.e(e);
                      ToastMessageShower.showToast(
                          "Failed to fetch search suggestions", context);
                    }
                  },
                  onSubmitted: (query) async {
                    startSearchQuery(
                        UniversalSearchRequest(searchString: query));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    contentPadding: const EdgeInsets.only(top: 11),
                    border: InputBorder.none,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            _controller.clear();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                        IconButton(
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => FilterScreen(
                                    previousSearch: widget.previousSearch)));
                          },
                          icon: const Icon(Icons.filter_alt),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: displayedSuggestions.isEmpty
              ? Text(
                  _controller.text == ""
                      ? searchHistoryEnabled
                          ? "No search history yet"
                          : "Search history disabled"
                      : "No search suggestions",
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center)
              : ListView.builder(
                  itemCount: displayedSuggestions.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                        contentPadding: const EdgeInsetsDirectional.only(
                            start: 16.0, end: 0.0),
                        title: Text(displayedSuggestions[index].searchString),
                        onTap: () {
                          _controller.text =
                              displayedSuggestions[index].searchString;
                          startSearchQuery(displayedSuggestions[index]);
                        },
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (displayedSuggestions[index].historySearch) ...[
                            IconButton(
                              icon: Icon(Icons.clear,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.55)),
                              onPressed: () {
                                DatabaseManager.removeFromSearchHistory(
                                    displayedSuggestions[index]);
                                setState(() {
                                  displayedSuggestions.removeAt(index);
                                });
                              },
                            )
                          ],
                          IconButton(
                            icon: Transform.flip(
                                flipX: true,
                                child: Icon(Icons.arrow_outward,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.55))),
                            onPressed: () {
                              _controller.text =
                                  displayedSuggestions[index].searchString;
                            },
                          )
                        ]));
                  },
                ),
        ));
  }
}
