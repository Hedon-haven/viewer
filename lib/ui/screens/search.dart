import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/search_handler.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/results.dart';

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
                onSubmitted: (query) async {
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
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          _controller.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      IconButton(
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
      body: const Center(
        child: Text('Search suggestions coming soon',
            style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
