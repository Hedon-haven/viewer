import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/screens/about.dart';
import 'package:hedon_viewer/ui/screens/search.dart';
import 'package:hedon_viewer/ui/screens/settings/settings_main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                        builder: (context) => const SettingsScreen()));
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
      body: SafeArea(child: _HomeScreenWidget()),
    );
  }
}

class _HomeScreenWidget extends StatefulWidget {
  @override
  State<_HomeScreenWidget> createState() => _HomeScreenWidgetState();
}

class _HomeScreenWidgetState extends State<_HomeScreenWidget> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Home screen coming soon"));
  }
}
