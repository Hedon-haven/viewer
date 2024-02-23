import 'package:flutter/material.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/search.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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
