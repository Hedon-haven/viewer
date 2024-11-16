import 'package:flutter/material.dart';

import '/backend/managers/database_manager.dart';
import '/backend/universal_formats.dart';
import '/ui/screens/video_list.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

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
        videoResults: getWatchHistory(),
        listType: "history",
        loadingHandler: null,
        searchRequest: null,
      )),
    );
  }
}
