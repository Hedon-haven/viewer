import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';

import 'custom_widgets/options_switch.dart';

class HomepageProvidersScreen extends StatefulWidget {
  const HomepageProvidersScreen({super.key});

  @override
  State<HomepageProvidersScreen> createState() =>
      _HomepageProvidersScreenState();
}

class _HomepageProvidersScreenState extends State<HomepageProvidersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Providers"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: PluginManager.allPlugins.length,
                  itemBuilder: (context, index) {
                    String title = PluginManager.allPlugins[index].pluginName;
                    String subTitle = PluginManager.allPlugins[index].pluginURL;
                    bool switchState = PluginManager.enabledHomepageProviders
                        .contains(PluginManager.allPlugins[index]);

                    return OptionsSwitch(
                      title: title,
                      subTitle: subTitle,
                      switchState: switchState,
                      onSelected: (value) {
                        if (value) {
                          PluginManager.enabledHomepageProviders
                              .add(PluginManager.allPlugins[index]);
                        } else {
                          PluginManager.enabledHomepageProviders
                              .remove(PluginManager.allPlugins[index]);
                        }
                        PluginManager.writeHomepageProvidersListToSettings();
                        switchState = value;
                      },
                    );
                  },
                ))));
  }
}
