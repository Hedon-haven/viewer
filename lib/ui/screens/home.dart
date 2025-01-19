import 'package:flutter/material.dart';

import '/services/loading_handler.dart';
import '/ui/widgets/future_widget.dart';
import '/utils/global_vars.dart';
import '/utils/universal_formats.dart';
import 'search.dart';
import 'video_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<UniversalVideoPreview>?> videoResults = Future.value([]);
  LoadingHandler loadingHandler = LoadingHandler();

  @override
  void initState() {
    super.initState();
    sharedStorage.getBool("homepage_enabled").then((value) {
      if (value!) {
        videoResults = loadingHandler.getHomePages(null);
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
          child: FutureWidget<bool?>(
              future: sharedStorage.getBool("homepage_enabled"),
              finalWidgetBuilder: (context, snapshotData) {
                return snapshotData!
                    ? VideoList(
                        videoList: videoResults,
                        listType: "homepage",
                        loadingHandler: loadingHandler,
                      )
                    : const Center(
                        child: Text(
                            "Homepage disabled in settings/appearance/enable homepage",
                            style: TextStyle(fontSize: 20, color: Colors.red)));
              })),
    );
  }
}
