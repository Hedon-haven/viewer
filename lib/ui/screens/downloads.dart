import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Future<List<UniversalSearchResult>> videoResults = Future.value([]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: const [],
      ),
      body: const Text("Coming soon"),
    );
  }
}
