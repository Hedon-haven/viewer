import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/plugin_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

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
  final randomChars =
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  TextEditingController generatedController = TextEditingController();

  String getRandomDirName() {
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => randomChars.codeUnitAt(random.nextInt(62))));
  }

  /// Recursive function to copy a directory into another
  /// Source: https://stackoverflow.com/a/76166248
  void copyDirectory(Directory source, Directory destination) {
    /// create destination folder if not exist
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    /// get all files from source (recursive: false is important here)
    source.listSync(recursive: false).forEach((entity) {
      final newPath = destination.path +
          Platform.pathSeparator +
          entity.path.split(Platform.pathSeparator).last;
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        copyDirectory(entity, Directory(newPath));
      }
    });
  }

  Future<Map<String, dynamic>> extractPlugin() async {
    try {
      logger.d("Prompting user to select a zip file");
      // Let the user pick a zip file
      FilePickerResult? pickedFile = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ["zip"]);

      // Create a temporary directory with random name to process the zip file
      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory("${tempDir.path}/${getRandomDirName()}");
      logger.d("Creating temp dir at ${outputDir.path}");
      await outputDir.create();

      // Extract the contents of the zip file into the temp dir
      for (final file in ZipDecoder().decodeBytes(
          File(pickedFile!.files.single.path!).readAsBytesSync())) {
        if (file.isFile) {
          logger.d(
              "Unpacking file ${file.name} to ${outputDir.path}/${file.name}");
          final data = file.content as List<int>;
          File("${outputDir.path}/${file.name}")
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory("${outputDir.path}/${file.name}").create(recursive: true);
        }
      }

      // Parse yaml
      if (!File("${outputDir.path}/plugin.yaml").existsSync()) {
        return {
          "codeName": "Error",
          "error":
              "${pickedFile.files.single.path} is not a valid plugin (plugin.yaml not found)"
        };
      }
      YamlMap pluginConfig =
          loadYaml(File("${outputDir.path}/plugin.yaml").readAsStringSync());

      // Check if plugin is already installed
      logger.d("Checking if plugin is already installed");
      if (PluginManager.allPlugins
          .any((plugin) => plugin.codeName == pluginConfig["codeName"])) {
        return {"codeName": "Error", "error": "Plugin already installed"};
      }

      // Check if current platform is supported by plugin
      logger.d("Checking if platform is supported by plugin");
      Map<String, List<String>> platformMap = {
        for (var item in pluginConfig["supportedPlatforms"])
          item.keys.first: List<String>.from(item.values.first)
      };
      if (platformMap[Platform.operatingSystem] != null) {
        // Get platform architecture
        String platformString = Platform.version;
        String platformArch = platformString.substring(
            platformString.lastIndexOf("_") + 1, platformString.length - 1);
        if (!platformMap[Platform.operatingSystem]!.contains(platformArch)) {
          return {
            "codeName": "Error",
            "error":
                "Your device is not supported by the plugin (Unsupported architecture: $platformArch)"
          };
        }
      } else {
        return {
          "codeName": "Error",
          "error":
              "Your device is not supported by the plugin (Unsupported platform: ${Platform.operatingSystem})"
        };
      }
      Map<String, dynamic> pluginMap = Map<String, dynamic>.from(pluginConfig);
      pluginMap["tempPluginPath"] = outputDir.path;
      return pluginMap;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> importAndTestPlugin(
      String tempPluginPath, String pluginCodeName) async {
    // Create plugin dir
    Directory appSupportDir = await getApplicationSupportDirectory();
    Directory pluginDir =
        Directory("${appSupportDir.path}/plugins/$pluginCodeName");
    if (pluginDir.existsSync()) {
      // TODO: Prompt user on what to do?
      logger.w(
          "Plugin directory for codename $pluginCodeName already exists! Deleting and recreating");
      pluginDir.deleteSync(recursive: true);
      pluginDir.createSync(recursive: true);
    }

    // Copy bin dir

    copyDirectory(
        Directory("$tempPluginPath/bin"), Directory("${pluginDir.path}/bin"));

    // symlink "binary" to the platform appropriate binary inside ./bin
    String platformString = Platform.version;
    String platformArch = platformString.substring(
        platformString.lastIndexOf("_") + 1, platformString.length - 1);
    try {
      // make binary executable
      final result = await Process.run('chmod', [
        '555',
        "${pluginDir.path}/bin/${Platform.operatingSystem}-$platformArch"
      ]);
      if (result.exitCode != 0) {
        throw Exception('Failed to make binary executable: ${result.stderr}');
      }
    } catch (e) {
      logger.e("Failed to make binary executable: $e");
      return false;
    }
    try {
      Link("${pluginDir.path}/bin/binaryLink")
          .createSync("./${Platform.operatingSystem}-$platformArch");
    } catch (e) {
      if (e is PathExistsException) {
        logger.e(
            "Cannot symlink to correct platform binary, aborting plugin install");
        return false;
      }
    }

    // conf dir is optional
    if (Directory("$tempPluginPath/conf").existsSync()) {
      copyDirectory(Directory("$tempPluginPath/conf"),
          Directory("${pluginDir.path}/conf"));
    } else {
      logger.i("Conf dir not found inside plugin zip");
    }

    // copy plugin.yaml
    logger.d(
        "Copying $tempPluginPath/plugin.yaml to ${pluginDir.path}/plugin.yaml");
    File("$tempPluginPath/plugin.yaml")
        .copySync("${pluginDir.path}/plugin.yaml");

    logger.i("Attempting to initialize plugin $pluginCodeName");
    try {
      PluginInterface tempPlugin = PluginInterface(pluginDir.path);
      tempPlugin.runInitTest();
    } catch (e) {
      logger.e("Failed to initialize plugin $pluginCodeName: $e");
      return false;
    }
    logger.i("Plugin initialization successful");

    logger.i("Reinitializing all plugins");

    setState(() {
      PluginManager.discoverAndLoadPlugins();
    });

    return true;
  }

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
                  Map<String, dynamic> plugin = await extractPlugin();
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
                                    importAndTestPlugin(
                                        plugin["tempPluginPath"],
                                        plugin["codeName"]);
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
