import 'package:flutter/material.dart';

import '/main.dart';
import 'custom_widgets/options_switch.dart';

class MiscScreen extends StatefulWidget {
  const MiscScreen({super.key});

  @override
  State<MiscScreen> createState() => _MiscScreenState();
}

class _MiscScreenState extends State<MiscScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Miscellaneous"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("keyboard_incognito_mode"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Enable keyboard incognito mode",
                              subTitle:
                                  "Instruct keyboard app to enable incognito mode (e.g. disable auto-suggest, learning of new words, etc.)",
                              switchState: snapshot.data!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("keyboard_incognito_mode", value));
                        })
                  ],
                ))));
  }
}
