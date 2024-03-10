import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_dialog.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _AppearanceScreenWidget()),
    );
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
                subtitle: Text(localStorage.getString("theme_mode")!),
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
                                localStorage.getString("theme_mode")!,
                            onSelected: (value) {
                              localStorage.setString("theme_mode", value);
                              setState(() {});
                            });
                      });
                })
          ],
        )));
  }
}
