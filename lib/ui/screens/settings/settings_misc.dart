import 'package:flutter/material.dart';

import '/backend/managers/database_manager.dart';
import '/main.dart';
import '/ui/toast_notification.dart';
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
                    OptionsSwitch(
                        title: "Enable keyboard incognito mode",
                        subTitle: "Instruct keyboard app to enable incognito mode (e.g. disable auto-suggest, learning of new words, etc.)",
                        switchState:
                            sharedStorage.getBool("keyboard_incognito_mode")!,
                        onToggled: (value) => sharedStorage.setBool(
                            "keyboard_incognito_mode", value)),
                  ],
                ))));
  }
}
