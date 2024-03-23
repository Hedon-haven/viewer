import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_switch.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Homepage"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: <Widget>[
                  OptionsSwitch(
                      title: "Enable Homepage",
                      subTitle: "Enable Homepage on app startup",
                      switchState: sharedStorage.getBool("homepage_enabled")!,
                      onSelected: (value) {
                        sharedStorage.setBool("homepage_enabled", value);
                      })
                ]))));
  }
}
