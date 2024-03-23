import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/video_list.dart';
import 'package:hedon_viewer/ui/screens/about.dart';
import 'package:hedon_viewer/ui/screens/search.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_main.dart';

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
    videoResults = PluginManager.getPluginByName(
            sharedStorage.getStringList("homepage_providers")![0])!
        .getHomePage(1);
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
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            SizedBox(
                height: MediaQuery.of(context).size.height * 0.12,
                child: DrawerHeader(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Image.asset("assets/logo/flame.png")),
                      Text(packageInfo.appName)
                    ]))),
            ListTile(
              title: const Text("Settings"),
              leading: const Icon(Icons.settings),
              onTap: () {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()))
                    .then((value) {
                  // Some settings modify the homepage -> need to update it after returning
                  setState(() {});
                });
              },
            ),
            ListTile(
              title: const Text("About"),
              leading: const Icon(Icons.info),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AboutScreen()));
              },
            ),
          ],
        ),
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
