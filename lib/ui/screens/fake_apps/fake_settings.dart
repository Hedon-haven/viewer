import 'dart:async';

import 'package:flutter/material.dart';

import '/ui/widgets/future_widget.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

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
    return FutureWidget<List<String>?>(
        future: sharedStorage.getStringList("fake_settings_list"),
        finalWidgetBuilder: (context, snapshotData) {
          return Scaffold(
              appBar: AppBar(
                title: Text("Reminders",
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              body: ListView(children: [
                OptionsSwitch(
                    title: "Force preferred network type",
                    switchState: snapshotData![0] == "1",
                    onToggled: (value) {
                      snapshotData[0] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshotData);
                      setState(() {});
                    }),
                OptionsSwitch(
                    title: "Enable advanced mode",
                    switchState: snapshotData[1] == "1",
                    onToggled: (value) {
                      snapshotData[1] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshotData);
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
                        switchState: snapshotData[2] == "1",
                        onToggled: (value) {
                          snapshotData[2] = value ? "1" : "0";
                          sharedStorage.setStringList(
                              "fake_settings_list", snapshotData);
                          setState(() {});
                        })),
                OptionsSwitch(
                    title: "Allow manual network selection in advanced mode",
                    switchState: snapshotData[3] == "1",
                    onToggled: (value) {
                      snapshotData[3] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshotData);
                      setState(() {});
                    }),
                OptionsSwitch(
                    title: "Enable always-on search",
                    switchState: snapshotData[4] == "1",
                    onToggled: (value) {
                      snapshotData[4] = value ? "1" : "0";
                      sharedStorage.setStringList(
                          "fake_settings_list", snapshotData);
                      setState(() {});
                    }),
              ]));
        });
  }
}
