import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_switch.dart';

class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HomePageScreenWidget();
  }
}

class _HomePageScreenWidget extends StatefulWidget {
  @override
  State<_HomePageScreenWidget> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<_HomePageScreenWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Homepage"),
        ),
        body: SafeArea(
            child: Column(children: <Widget>[
          OptionsSwitch(
              title: "Enable Homepage",
              subTitle: "Enable Homepage on app startup",
              switchState: sharedStorage.getBool("homepage_enabled")!,
              onSelected: (value) {
                sharedStorage.setBool("homepage_enabled", value);
                // Update home screen
                ViewerApp.of(context)?.setState(() {});
              })
        ])));
  }
}
