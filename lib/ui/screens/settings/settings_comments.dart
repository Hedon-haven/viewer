import 'package:flutter/material.dart';

import '/main.dart';
import '/ui/widgets/options_switch.dart';

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
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("comments_hide_hidden"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Hide hidden/spam comments",
                              subTitle:
                                  "Hide comments that were hidden by the creator or marked as spam.",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("comments_hide_hidden", value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("comments_hide_negative"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Hide comments with negative ratings",
                              subTitle:
                                  "Hide comments that have a rating of less than 0",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("comments_hide_negative", value));
                        }),
                    ListTile(
                        title: const Text("Comment text filters"),
                        subtitle: const Text("Apply text filters to comments"),
                        onTap: () => showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Comment text filters"),
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
                                    FutureBuilder<bool?>(
                                        future: sharedStorage
                                            .getBool("comments_filter_links"),
                                        builder: (context, snapshot) {
                                          // only build when data finished loading
                                          if (snapshot.data == null) {
                                            return const SizedBox();
                                          }
                                          return OptionsSwitch(
                                              title: "Hide comments with links",
                                              subTitle:
                                                  "Comments with links will be hidden",
                                              switchState: snapshot.data!,
                                              onToggled: (value) async =>
                                                  await sharedStorage.setBool(
                                                      "comments_filter_links",
                                                      value));
                                        }),
                                    FutureBuilder<bool?>(
                                        future: sharedStorage.getBool(
                                            "comments_filter_non_ascii"),
                                        builder: (context, snapshot) {
                                          // only build when data finished loading
                                          if (snapshot.data == null) {
                                            return const SizedBox();
                                          }
                                          return OptionsSwitch(
                                              title: "Hide non-ascii comments",
                                              subTitle:
                                                  "Hide comments with non-ascii (non-english) text",
                                              switchState: snapshot.data!,
                                              onToggled: (value) async =>
                                                  await sharedStorage.setBool(
                                                      "comments_filter_non_ascii",
                                                      value));
                                        })
                                  ],
                                ),
                              );
                            })),
                  ],
                ))));
  }
}
