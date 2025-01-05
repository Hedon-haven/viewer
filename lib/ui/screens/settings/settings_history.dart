import 'package:flutter/material.dart';

import '/services/database_manager.dart';
import '/main.dart';
import '/ui/toast_notification.dart';
import 'custom_widgets/options_switch.dart';

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
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("History"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("enable_watch_history"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Enable watch history",
                              subTitle: "Keep track of watched videos",
                              switchState: snapshot.data!,
                              onToggled: (value) => sharedStorage.setBool(
                                  "enable_watch_history", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear watch history"),
                        onTap: () {
                          deleteAllFrom("watch_history");
                          ToastMessageShower.showToast(
                              "Watch history cleared", context);
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("enable_search_history"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Enable search history",
                              subTitle: "Keep track of search queries",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("enable_search_history", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear search history"),
                        onTap: () {
                          deleteAllFrom("search_history");
                          ToastMessageShower.showToast(
                              "Search history cleared", context);
                        }),
                  ],
                ))));
  }
}
