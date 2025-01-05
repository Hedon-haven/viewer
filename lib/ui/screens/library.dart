import 'package:flutter/material.dart';

import '/backend/universal_formats.dart';
import '/services/database_manager.dart';
import 'video_list.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<List<UniversalVideoPreview>> videoResults = Future.value([]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              tileColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              leading: Icon(Icons.history),
                              trailing: Icon(Icons.arrow_forward),
                              title: Text("History"),
                              textColor: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              titleTextStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const HistoryScreen())))),
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            tileColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: Icon(Icons.star),
                            trailing: Icon(Icons.arrow_forward),
                            title: Text("Favorites"),
                            textColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const FavoritesScreen())),
                          )),
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            tileColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: Icon(Icons.download),
                            trailing: Icon(Icons.arrow_forward),
                            title: Text("Downloads"),
                            textColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const DownloadsScreen())),
                          ))
                    ]))));
  }
}

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
        actions: const [],
      ),
      body: SafeArea(
          child: VideoList(
        videoList: getWatchHistory(),
        listType: "history",
      )),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: const [],
      ),
      body: SafeArea(
          child: VideoList(
        videoList: getFavorites(),
        listType: "favorites",
      )),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        actions: const [],
      ),
      body: SafeArea(child: Text("Downloads coming soon")),
    );
  }
}
