import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/plugin_manager.dart';
import 'package:hedon_viewer/ui/custom_widgets/options_switch.dart';

class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PluginsScreenWidget();
  }
}

class _PluginsScreenWidget extends StatefulWidget {
  @override
  State<_PluginsScreenWidget> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<_PluginsScreenWidget> {
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
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: PluginManager.allPlugins.length,
                  itemBuilder: (context, index) {
                    String title = PluginManager.allPlugins[index].pluginName;
                    String subTitle = PluginManager.allPlugins[index].pluginURL;
                    bool switchState = PluginManager.enabledPlugins
                        .contains(PluginManager.allPlugins[index]);

                    return OptionsSwitch(
                      title: title,
                      subTitle: subTitle,
                      switchState: switchState,
                      onSelected: (value) {
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
                    );
                  },
                ))));
  }
}
