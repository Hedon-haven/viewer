import 'dart:async';

import 'package:flutter/material.dart';

import '/main.dart';
import '/ui/screens/settings/custom_widgets/options_switch.dart';

class FakeSettingsScreen extends StatefulWidget {
  final Function parentStopConcealing;

  const FakeSettingsScreen({super.key, required this.parentStopConcealing});

  @override
  State<FakeSettingsScreen> createState() => _FakeSettingsScreenState();
}

class _FakeSettingsScreenState extends State<FakeSettingsScreen> {
  Timer? longPressTimer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>?>(
        future: sharedStorage.getStringList("fake_settings_list"),
        builder: (context, snapshot) {
          // only build when data finished loading
          if (snapshot.data == null) {
            return const SizedBox();
          }
          return Scaffold(
              appBar: AppBar(
                title: Text("Reminders",
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              body: ListView(children: [
                OptionsSwitch(
                    title: "Force preferred network type",
                    switchState: snapshot.data![0] == "1",
                    onToggled: (value) {
                      snapshot.data![0] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshot.data!);
                      setState(() {});
                    }),
                OptionsSwitch(
                    title: "Enable advanced mode",
                    switchState: snapshot.data![1] == "1",
                    onToggled: (value) {
                      snapshot.data![1] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshot.data!);
                      setState(() {});
                    }),
                GestureDetector(
                    onLongPressStart: (_) {
                      logger.i("Long press started");
                      longPressTimer = Timer(const Duration(seconds: 5), () {
                        logger.i("Long press successful");
                        logger.i("Unconcealing app");
                        widget.parentStopConcealing();
                      });
                    },
                    onLongPressEnd: (_) {
                      logger
                          .i("Long press ended prematurely. Not unconcealing.");
                      longPressTimer?.cancel();
                    },
                    child: OptionsSwitch(
                        title: "Show signal strength in advanced mode",
                        switchState: snapshot.data![2] == "1",
                        onToggled: (value) {
                          snapshot.data![2] = value ? "1" : "0";
                          sharedStorage.setStringList(
                              "fake_settings_list", snapshot.data!);
                          setState(() {});
                        })),
                OptionsSwitch(
                    title: "Allow manual network selection in advanced mode",
                    switchState: snapshot.data![3] == "1",
                    onToggled: (value) {
                      snapshot.data![3] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshot.data!);
                      setState(() {});
                    }),
                OptionsSwitch(
                    title: "Enable always-on search",
                    switchState: snapshot.data![4] == "1",
                    onToggled: (value) {
                      snapshot.data![4] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshot.data!);
                      setState(() {});
                    }),
              ]));
        });
  }
}
