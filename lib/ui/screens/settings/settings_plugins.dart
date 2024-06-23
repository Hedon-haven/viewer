import 'package:flutter/material.dart';

import '/backend/managers/plugin_manager.dart';
import 'custom_widgets/options_switch.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  @override
  void initState() {
    super.initState();
    print("Checking if contained");
    print(PluginManager.enabledHomepageProviders);
    print(PluginManager.enabledHomepageProviders
        .contains(PluginManager.allPlugins[0]));
    print(PluginManager.enabledHomepageProviders
        .contains(PluginManager.allPlugins[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Plugins"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: PluginManager.allPlugins.length,
                  itemBuilder: (context, index) {
                    String title = PluginManager.allPlugins[index].name;
                    String subTitle = PluginManager.allPlugins[index].providerUrl;
                    bool switchState = PluginManager.enabledPlugins
                        .contains(PluginManager.allPlugins[index]);
                    bool homeButtonState = PluginManager
                        .enabledHomepageProviders
                        .contains(PluginManager.allPlugins[index]);

                    return OptionsSwitch(
                      title: title,
                      subTitle: subTitle,
                      switchState: switchState,
                      showExtraHomeButton: true,
                      homeButtonState: homeButtonState,
                      onToggled: (value) {
                        if (value) {
                          PluginManager.enabledPlugins
                              .add(PluginManager.allPlugins[index]);
                        } else {
                          PluginManager.enabledPlugins
                              .remove(PluginManager.allPlugins[index]);
                        }
                        PluginManager.writePluginListToSettings();
                        switchState = value;
                      },
                      onToggledHomeButton: (value) {
                        if (value) {
                          PluginManager.enabledHomepageProviders
                              .add(PluginManager.allPlugins[index]);
                        } else {
                          PluginManager.enabledHomepageProviders
                              .remove(PluginManager.allPlugins[index]);
                        }
                        PluginManager.writeHomepageProvidersListToSettings();
                        homeButtonState = value;
                      },
                    );
                  },
                ))));
  }
}
