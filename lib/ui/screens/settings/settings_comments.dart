import 'package:flutter/material.dart';

import '/main.dart';
import 'custom_widgets/options_switch.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Comments"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    OptionsSwitch(
                        title: "Hide hidden/spam comments",
                        subTitle:
                            "Hide comments that were hidden by the creator or marked as spam.",
                        switchState:
                            sharedStorage.getBool("comments_hide_hidden")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "comments_hide_hidden", value)),
                    OptionsSwitch(
                        title: "Hide comments with negative ratings",
                        subTitle:
                        "Hide comments that have a rating of less than 0",
                        switchState:
                        sharedStorage.getBool("comments_hide_negative")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "comments_hide_negative", value)),
                    ListTile(
                        title: const Text("Comment text filters"),
                        subtitle:
                            const Text("Apply local text filters to comments"),
                        onTap: () => showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Comment filters"),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Center(child: const Text("Ok")),
                                  ),
                                ],
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OptionsSwitch(
                                        title: "Hide comments with links",
                                        subTitle:
                                            "Comments with links will be hidden",
                                        switchState:
                                            sharedStorage.getBool(
                                                "comments_filter_links")!,
                                        onToggled: (value) => sharedStorage.setBool(
                                            "comments_filter_links", value)),
                                    OptionsSwitch(
                                        title: "Hide non-ascii comments",
                                        subTitle: "Hide comments with non-ascii (non-english) text",
                                        switchState:
                                        sharedStorage.getBool(
                                            "comments_filter_non_ascii")!,
                                        onToggled: (value) => sharedStorage.setBool(
                                            "comments_filter_non_ascii", value)),
                                  ],
                                ),
                              );
                            })),
                  ],
                ))));
  }
}
