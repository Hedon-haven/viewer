import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '/backend/managers/plugin_manager.dart';
import '/main.dart';
import '/ui/toast_notification.dart';
import 'custom_widgets/options_switch.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Plugins"),
          actions: [
            IconButton(
              icon: Icon(
                  color: Theme.of(context).colorScheme.primary, Icons.download),
              onPressed: () async {
                if (!thirdPartyPluginWarningShown) {
                  await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                            title:
                                const Center(child: Text("Third party notice")),
                            content: const Text(
                                "Importing plugins from untrusted sources may put your device at risk! "
                                "The developers of Hedon Haven take no responsibility for any damage or "
                                "unintended consequences of using plugins from untrusted sources.",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  // close popup
                                  Navigator.pop(context);
                                },
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  // close popup
                                  Navigator.pop(context);
                                  thirdPartyPluginWarningShown = true;
                                },
                                child: const Text(
                                    "Accept the risks and continue",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              )
                            ]);
                      });
                }
                // Check if user has accepted the warning in the prev showDialog
                if (thirdPartyPluginWarningShown) {
                  logger.d("Prompting user to select a zip file");
                  // Let the user pick a zip file
                  Map<String, dynamic> plugin = await PluginManager()
                      .extractPlugin(await FilePicker.platform.pickFiles(
                          type: FileType.custom, allowedExtensions: ["zip"]));
                  if (plugin["codeName"] == "Error") {
                    ToastMessageShower.showToast(plugin["error"], context, 10);
                  } else {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                              title: const Center(child: Text("Import plugin")),
                              content: Text(
                                  "Are you sure you want to import this plugin?\n"
                                  "\nProvider URL: ${plugin["providerUrl"]}"
                                  "\nName: ${plugin["prettyName"]} (${plugin["codeName"]})"
                                  "\nVersion: ${plugin["version"]}"
                                  "\nDeveloper: ${plugin["developer"]}"
                                  "\nDescription: ${plugin["description"]}"),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    // close popup
                                    Navigator.pop(context);
                                  },
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // close popup
                                    Navigator.pop(context);
                                    setState(() {
                                      PluginManager().importAndTestPlugin(
                                          plugin["tempPluginPath"],
                                          plugin["codeName"]);
                                    });
                                  },
                                  child: const Text("Import plugin",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                )
                              ]);
                        });
                  }
                }
              },
            ),
          ],
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: PluginManager.allPlugins.length,
                  itemBuilder: (context, index) {
                    String title = PluginManager.allPlugins[index].prettyName;
                    String subTitle =
                        PluginManager.allPlugins[index].providerUrl;

                    return OptionsSwitch(
                      // TODO: MAYBE: rework this UI to make it more obvious to why its there and what it means
                      leadingWidget:
                          PluginManager.allPlugins[index].isOfficialPlugin
                              ? const Icon(
                                  size: 30, color: Colors.blue, Icons.verified)
                              : const Icon(
                                  size: 30,
                                  color: Colors.redAccent,
                                  Icons.extension),
                      title: title,
                      subTitle: subTitle,
                      switchState: PluginManager.enabledPlugins
                          .contains(PluginManager.allPlugins[index]),
                      showExtraSettingsButton: true,
                      onToggled: (toggleValue) {
                        if (toggleValue) {
                          PluginManager.enablePlugin(
                                  PluginManager.allPlugins[index])
                              .then((initValue) {
                            if (!initValue) {
                              ToastMessageShower.showToast(
                                  "Failed to enable ${PluginManager.allPlugins[index].prettyName}",
                                  context);
                              PluginManager.disablePlugin(
                                  PluginManager.allPlugins[index]);
                            }
                          });
                        } else {
                          PluginManager.disablePlugin(
                              PluginManager.allPlugins[index]);
                        }
                        setState(() {});
                      },
                      onPressedSettingsButton: () {
                        // open popup with options
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                  title: Text("$title options"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OptionsSwitch(
                                          title: "Results provider",
                                          subTitle:
                                          "Use this plugin to provide video results",
                                          switchState: PluginManager
                                              .enabledResultsProviders
                                              .contains(PluginManager
                                              .allPlugins[index]),
                                          onToggled: (value) {
                                            if (value) {
                                              PluginManager
                                                  .enableProvider(
                                                  PluginManager
                                                      .allPlugins[index], "results");
                                            } else {
                                              PluginManager
                                                  .disableProvider(
                                                  PluginManager
                                                      .allPlugins[index], "results");
                                            }
                                            setState(() {});
                                          }),
                                      OptionsSwitch(
                                          title: "Homepage provider",
                                          subTitle:
                                              "Show this plugins results on the homepage",
                                          switchState: PluginManager
                                              .enabledHomepageProviders
                                              .contains(PluginManager
                                                  .allPlugins[index]),
                                          onToggled: (value) {
                                            if (value) {
                                              PluginManager
                                                  .enableProvider(
                                                      PluginManager
                                                          .allPlugins[index], "homepage");
                                            } else {
                                              PluginManager
                                                  .disableProvider(
                                                      PluginManager
                                                          .allPlugins[index], "homepage");
                                            }
                                            setState(() {});
                                          }),
                                      OptionsSwitch(
                                          title: "Search suggestions provider",
                                          subTitle:
                                              "Use this plugin to provide search suggestions",
                                          switchState: PluginManager
                                              .enabledSearchSuggestionsProviders
                                              .contains(PluginManager
                                                  .allPlugins[index]),
                                          onToggled: (value) {
                                            if (value) {
                                              PluginManager
                                                  .enableProvider(
                                                      PluginManager
                                                          .allPlugins[index], "search_suggestions");
                                            } else {
                                              PluginManager
                                                  .disableProvider(
                                                      PluginManager
                                                          .allPlugins[index], "search_suggestions");
                                            }
                                            setState(() {});
                                          })
                                    ],
                                  ),
                                  actions: <Widget>[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        // TODO: Fix background color of button
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                      ),
                                      onPressed: () {
                                        // Close popup
                                        Navigator.pop(context);
                                      },
                                      child: Text("Apply",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary)),
                                    )
                                  ]);
                            });
                      },
                    );
                  },
                ))));
  }
}
