import 'package:flutter/material.dart';

import '/backend/managers/database_manager.dart';
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
                    OptionsSwitch(
                        title: "Enable watch history",
                        subTitle: "Keep track of watched videos",
                        switchState:
                            sharedStorage.getBool("enable_watch_history")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "enable_watch_history", value)),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear watch history"),
                        onTap: () {
                          DatabaseManager.deleteAllFrom("watch_history");
                          ToastMessageShower.showToast(
                              "Watch history cleared", context);
                        }),
                    OptionsSwitch(
                        title: "Enable search history",
                        subTitle: "Keep track of search queries",
                        switchState:
                            sharedStorage.getBool("enable_search_history")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "enable_search_history", value)),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear search history"),
                        onTap: () {
                          DatabaseManager.deleteAllFrom("search_history");
                          ToastMessageShower.showToast(
                              "Search history cleared", context);
                        }),
                  ],
                ))));
  }
}
