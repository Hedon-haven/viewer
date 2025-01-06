import 'dart:io';

import 'package:flutter/material.dart';

import '/services/database_manager.dart';
import '/services/loading_handler.dart';
import '/services/plugin_manager.dart';
import '/ui/screens/filters/filters.dart';
import '/ui/screens/results.dart';
import '/ui/screens/settings/settings_plugins.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';

class SearchScreen extends StatefulWidget {
  UniversalSearchRequest previousSearch;

  SearchScreen({super.key, required this.previousSearch});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool keyboardIncognitoMode = false;
  bool searchHistoryEnabled = false;
  bool noSearchProvidersEnabled = false;
  List<UniversalSearchRequest>? searchSuggestions = [];
  List<UniversalSearchRequest> historySuggestions = [];

  @override
  void initState() {
    super.initState();
    // apply old filter settings
    _controller.text = widget.previousSearch.searchString;

    // Set search suggestions to search history and update to show them
    getSearchHistory()
        .then((value) => setState(() => historySuggestions = value));

    // Check if search history is disabled
    sharedStorage.getBool("enable_search_history").then((value) {
      logger.d("Search history enabled: $value");
      setState(() => searchHistoryEnabled = value!);
    });

    // Set keyboard settings
    sharedStorage.getBool("keyboard_incognito_mode").then((value) {
      setState(() => keyboardIncognitoMode = value!);
    });

    // Check if there are search suggestion providers
    if (PluginManager.enabledSearchSuggestionsProviders.isEmpty) {
      setState(() => noSearchProvidersEnabled = true);
      logger.w("No search suggestion providers enabled");
    }

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
    List<UniversalSearchRequest>? displayedSuggestions =
        searchSuggestions?.isNotEmpty ?? true
            ? searchSuggestions
            : historySuggestions;
    logger.d("Search suggestions not empty?: ${searchSuggestions?.isNotEmpty}");
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
                  // this only works on android
                  enableSuggestions: !keyboardIncognitoMode,
                  // on ios private mode is tied to autocorrect
                  autocorrect: !keyboardIncognitoMode && Platform.isIOS,
                  onChanged: (searchString) async {
                    searchSuggestions = await LoadingHandler()
                        .getSearchSuggestions(searchString);
                    setState(() {});
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
          // null means error
          // empty means no results found
          child: displayedSuggestions?.isEmpty ?? true
              ? Column(children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 50, bottom: 30),
                      child: Text(
                          _controller.text == ""
                              ? searchHistoryEnabled
                                  ? "No search history yet"
                                  : "Search history disabled"
                              : displayedSuggestions == null
                                  ? noSearchProvidersEnabled
                                      ? "No search providers enabled"
                                      : "Error getting search suggestions"
                                  : "No search suggestions",
                          style: const TextStyle(fontSize: 20),
                          textAlign: TextAlign.center)),
                  if (noSearchProvidersEnabled && _controller.text != "") ...[
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
                          // Re-check if there are search suggestion providers
                          if (PluginManager.enabledResultsProviders.isEmpty) {
                            setState(() => noSearchProvidersEnabled = true);
                            logger.w("No search suggestion providers enabled");
                          }
                          searchSuggestions = await LoadingHandler()
                              .getSearchSuggestions(_controller.text);
                          setState(() {});
                        })
                  ]
                ])
              : ListView.builder(
                  // sometimes this is null -> make sure its at least 0
                  itemCount: displayedSuggestions?.length ?? 0,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                        contentPadding: const EdgeInsetsDirectional.only(
                            start: 16.0, end: 0.0),
                        title: Text(displayedSuggestions![index].searchString),
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
                                removeFromSearchHistory(
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
