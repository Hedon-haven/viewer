import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/search_handler.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/results.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';

class SearchScreen extends StatelessWidget {
  final UniversalSearchRequest previousSearch;

  const SearchScreen({super.key, required this.previousSearch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: _SearchWidget(
        previousSearch: previousSearch,
      )),
    );
  }
}

class _SearchWidget extends StatefulWidget {
  final UniversalSearchRequest previousSearch;

  const _SearchWidget({required this.previousSearch});

  @override
  State<_SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<_SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool searchQueryRunning = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0.0,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: (query) async {
                  if (!searchQueryRunning) {
                    setState(() {
                      searchQueryRunning = true;
                    });
                    NavigatorState navigator = Navigator.of(context);
                    List<UniversalSearchResult> videoResults =
                        await SearchHandler().search(
                            UniversalSearchRequest(searchString: query), 1);

                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => ResultsScreen(
                          videoResults: videoResults,
                        ),
                      ),
                    );
                    setState(() {
                      searchQueryRunning = false;
                    });
                  } else {
                    ToastMessageShower.showToast("Search already running");
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
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
                          print("Search filters not yet implemented");
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
      // TODO: Add cancel button
      body: searchQueryRunning
          ? const Center(child: CircularProgressIndicator())
          : const Center(
              child: Text('Search suggestions coming soon',
                  style: TextStyle(fontSize: 24)),
            ),
    );
  }
}
