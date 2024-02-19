import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/search_handler.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/plugins/xhamster.dart';
import 'package:hedon_viewer/ui/screens/results.dart';
import 'package:hedon_viewer/ui/screens/video_player.dart';

class SearchScreenWidget extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
      IconButton(
        icon: const Icon(Icons.filter_alt),
        onPressed: () {
          print("Search fiters not yet implemented");
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  // Future<List<UniversalSearchResult>> results =
  //         SearchHandler().search(UniversalSearchRequest(searchString: query), 1);

  @override
  Widget buildResults(BuildContext context) {
    performSearch(context);
    return Container(); // basically return nothing, as we go to another screen anyways
  }

  void performSearch(BuildContext context) async {
    List<UniversalSearchResult> asd = await SearchHandler()
        .search(UniversalSearchRequest(searchString: query), 1);
    // This is to avoid difficult to debug errors. Doubt its really needed here, but it gets rid of the IDE warning
    if (!context.mounted) {
      throw Exception("Context is not mounted anymore in performSearch???");
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ResultsScreen(
                  videoResults: asd,
                )));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text(
        'Search suggestions coming soon',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}
