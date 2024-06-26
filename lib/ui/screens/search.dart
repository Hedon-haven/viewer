import 'package:flutter/material.dart';

import '/backend/managers/search_manager.dart';
import '/backend/universal_formats.dart';
import '/ui/screens/filters/filters.dart';
import '/ui/screens/results.dart';

class SearchScreen extends StatefulWidget {
  UniversalSearchRequest previousSearch;

  SearchScreen({super.key, required this.previousSearch});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> searchSuggestions = [];

  @override
  void initState() {
    super.initState();
    // apply old filter settings
    _controller.text = widget.previousSearch.searchString;
    // Request focus when the widget is initialized
    Future.delayed(Duration.zero, () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void startSearchQuery(String query) async {
    SearchHandler searchHandler = SearchHandler();
    widget.previousSearch.searchString = query;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          videoResults: searchHandler.getResults(widget.previousSearch),
          searchRequest: widget.previousSearch,
          searchHandler: searchHandler,
        ),
      ),
    )
        .then((value) {
      _focusNode.requestFocus();
    }); // Bring up keyboard on return from results screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // TODO: Find workaround for weird graphical glitch on linux(or all desktops)
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
                    searchSuggestions = await SearchHandler()
                        .getSearchSuggestions(searchString);
                    setState(() {});
                  },
                  onSubmitted: (query) async {
                    startSearchQuery(query);
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
                            Navigator.of(context)
                                .push(MaterialPageRoute(
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
          child: ListView.builder(
            itemCount: searchSuggestions.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                  contentPadding:
                      const EdgeInsetsDirectional.only(start: 16.0, end: 0.0),
                  title: Text(searchSuggestions[index]),
                  onTap: () {
                    _controller.text = searchSuggestions[index];
                    startSearchQuery(searchSuggestions[index]);
                  },
                  trailing: IconButton(
                    icon: Transform.flip(
                        flipX: true,
                        child: Icon(Icons.arrow_outward,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.55))),
                    onPressed: () {
                      _controller.text = searchSuggestions[index];
                    },
                  ));
            },
          ),
        ));
  }
}
