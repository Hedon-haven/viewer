import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';

import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Privacy"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureBuilder<bool?>(
                        future: sharedStorage.getBool("hide_app_preview"),
                        builder: (context, snapshot) {
                          // only build when data finished loading
                          if (snapshot.data == null) {
                            return const SizedBox();
                          }
                          return OptionsSwitch(
                              title: "Hide app preview",
                              subTitle: "Hide app preview in app switcher",
                              switchState: snapshot.data!,
                              onToggled: (value) async {
                                await sharedStorage.setBool(
                                    "hide_app_preview", value);
                                // Force an immediate update
                                if (Platform.isAndroid || Platform.isIOS) {
                                  if (!value) {
                                    SecureAppSwitcher.off();
                                  } else {
                                    SecureAppSwitcher.on();
                                  }
                                }
                                // the hidePreview var is from main.dart
                                setState(() => hidePreview = value);
                              });
                        }),
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
