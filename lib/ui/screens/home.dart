import 'package:flutter/material.dart';

import '/backend/managers/loading_handler.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import 'search.dart';
import 'video_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<UniversalVideoPreview>> videoResults = Future.value([]);
  LoadingHandler loadingHandler = LoadingHandler();

  @override
  void initState() {
    super.initState();
    sharedStorage.getBool("homepage_enabled").then((value) {
      if (value!) {
        videoResults = loadingHandler.getSearchResults();
      }
    });
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
          child: FutureBuilder<bool?>(
              future: sharedStorage.getBool("homepage_enabled"),
              builder: (context, snapshot) {
                // only build when data finished loading
                if (snapshot.data == null) {
                  return const SizedBox();
                }
                return snapshot.data!
                    ? VideoList(
                        videoResults: videoResults,
                        listType: "homepage",
                        loadingHandler: loadingHandler,
                        searchRequest: null,
                      )
                    : const Center(
                        child: Text(
                            "Homepage disabled in settings/appearance/enable homepage",
                            style: TextStyle(fontSize: 20, color: Colors.red)));
              })),
    );
  }
}
