import 'package:flutter/material.dart';

import '/backend/managers/loading_handler.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/ui/screens/search.dart';
import '/ui/screens/video_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<UniversalSearchResult>> videoResults = Future.value([]);
  LoadingHandler loadingHandler = LoadingHandler();

  @override
  void initState() {
    super.initState();
    // TODO: Use multiple homepage providers
    if (sharedStorage.getBool("homepage_enabled")!) {
      videoResults = loadingHandler.getSearchResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: [
          IconButton(
            icon: Icon(
                color: Theme.of(context).colorScheme.primary, Icons.search),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SearchScreen(
                            previousSearch: UniversalSearchRequest(),
                          )));
            },
          ),
        ],
      ),
      body: SafeArea(
          child: sharedStorage.getBool("homepage_enabled")!
              ? VideoList(
                  videoResults: videoResults,
                  listType: "homepage",
                  loadingHandler: loadingHandler,
                  searchRequest: null,
                )
              : const Center(
                  child: Text(
                      "Homepage disabled in settings/appearance/enable homepage",
                      style: TextStyle(fontSize: 20, color: Colors.red)))),
    );
  }
}
