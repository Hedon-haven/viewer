import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/screens/video_list.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Future<List<UniversalSearchResult>> videoResults = Future.value([]);

  @override
  void initState() {
    super.initState();

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
        // TODO: add search to downloads
        actions: const [],
      ),
      body: SafeArea(
          child: VideoList(
        videoResults: videoResults,
        listType: "downloads",
      )),
    );
  }
}
