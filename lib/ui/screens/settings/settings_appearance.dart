import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_dialog.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppearanceScreenWidget();
  }
}

class _AppearanceScreenWidget extends StatefulWidget {
  @override
  State<_AppearanceScreenWidget> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<_AppearanceScreenWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Plugins"),
        ),
        body: SafeArea(
            child: Column(
          children: <Widget>[
            ListTile(
                title: const Text('Theme'),
                subtitle: Text(sharedStorage.getString("theme_mode")!),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return OptionsDialog(
                            title: "Theme",
                            options: const [
                              "Follow device theme",
                              "Light theme",
                              "Dark theme"
                            ],
                            selectedOption:
                                sharedStorage.getString("theme_mode")!,
                            onSelected: (value) {
                              sharedStorage.setString("theme_mode", value);
                              // TODO: Fix visual glitch when user returns to previous screen
                              ViewerApp.of(context)?.setState(() {});
                            });
                      });
                })
          ],
        )));
  }
}
