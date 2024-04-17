import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/screens/search.dart';
import 'package:hedon_viewer/ui/screens/video_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<UniversalSearchResult>> videoResults = Future.value([]);

  @override
  void initState() {
    super.initState();
    // TODO: Use multiple providers
    if (sharedStorage.getBool("homepage_enabled")!) {
      videoResults = PluginManager.getPluginByName(
              sharedStorage.getStringList("homepage_providers")![0])!
          .getHomePage(1);
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
                )
              : const Center(
                  child: Text("Homepage disabled in settings",
                      style: TextStyle(fontSize: 20, color: Colors.red)))),
    );
  }
}
