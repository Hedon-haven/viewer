import 'package:flutter/material.dart';

import '/services/database_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/future_widget.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

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
                    FutureWidget<bool?>(
                        future: sharedStorage.getBool("history_watch"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Enable watch history",
                              subTitle: "Keep track of watched videos",
                              switchState: snapshotData!,
                              onToggled: (value) => sharedStorage.setBool(
                                  "history_watch", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear watch history"),
                        onTap: () {
                          deleteAllFrom("watch_history");
                          showToast("Watch history cleared", context);
                        }),
                    FutureWidget<bool?>(
                        future: sharedStorage.getBool("history_search"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Enable search history",
                              subTitle: "Keep track of search queries",
                              switchState: snapshotData!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("history_search", value));
                        }),
                    ListTile(
                        trailing: const Icon(Icons.clear),
                        title: const Text("Clear search history"),
                        onTap: () {
                          deleteAllFrom("search_history");
                          showToast("Search history cleared", context);
                        }),
                  ],
                ))));
  }
}
