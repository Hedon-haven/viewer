import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/database_manager.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/ui/screens/video_list.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<UniversalSearchResult>> videoResults = Future.value([]);

  @override
  void initState() {
    super.initState();
    videoResults = DatabaseManager.getWatchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        // TODO: add search to history
        actions: const [],
      ),
      body: SafeArea(
          child: VideoList(
        videoResults: videoResults,
        listType: "history",
      )),
    );
  }
}
