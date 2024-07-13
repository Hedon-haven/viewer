import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hedon_viewer/backend/managers/icon_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '/backend/plugin_interface.dart';
import '/main.dart';
import '/plugins/official_plugins_tracker.dart';

class PluginManager {
  // make the plugin manager a singleton.
  // This way any part of the app can access the plugins, without having to re-initialize them
  static final PluginManager _instance = PluginManager._init();

  PluginManager._init() {
    discoverAndLoadPlugins();
  }

  factory PluginManager() {
    return _instance;
  }

  /// Contains all PluginInterfaces of all valid plugins in the plugins dir, no matter if enabled or not
  static List<PluginInterface> allPlugins = [];

  /// List of all the currently enabled plugins, stored as PluginInterfaces and ready to be used
  static List<PluginInterface> enabledPlugins = [];

  /// List of all the currently enabled homepage providing plugins, stored as PluginInterfaces and ready to be used
  static List<PluginInterface> enabledHomepageProviders = [];
  static Directory pluginsDir = Directory("");

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

  /// Discover all plugins and loading according to settings in sharedStorage
  static Future<void> discoverAndLoadPlugins() async {
    // Set pluginsDir if not already set
    if (pluginsDir.path.isEmpty) {
      // set pluginPath for the whole manager
      Directory appSupportDir = await getApplicationSupportDirectory();
      pluginsDir = Directory("${appSupportDir.path}/plugins");
    }

    // Get cache path
    Directory cachePath = await getApplicationCacheDirectory();

    // Empty plugin lists
    allPlugins = [];
    enabledPlugins = [];
    enabledHomepageProviders = [];

    // get list of all enabled plugins in settings
    List<String> enabledPluginsFromSettings =
        sharedStorage.getStringList("enabled_plugins") ?? [];
    List<String> enabledHomepageProvidersFromSettings =
        sharedStorage.getStringList("homepage_providers") ?? [];

    // Init official plugins first
    for (var plugin in OfficialPluginsTracker().getAllPlugins()) {
      allPlugins.add(plugin);
      if (enabledPluginsFromSettings.contains(plugin.codeName)) {
        enabledPlugins.add(plugin);
        // create a separate cache dir for each plugin
        Directory cacheDir = Directory("${cachePath.path}/plugins/${plugin.codeName}");
        if (!cacheDir.existsSync()) {
          cacheDir.create(recursive: true);
        }
      }
      if (enabledHomepageProvidersFromSettings.contains(plugin.codeName)) {
        enabledHomepageProviders.add(plugin);
      }
    }

    // If pluginsDir doesn't exist, no need to check for third party plugins inside it
    if (!pluginsDir.existsSync()) {
      pluginsDir.createSync();
      return;
    }

    // find third party plugins and load them
    for (var dir in pluginsDir.listSync().whereType<Directory>()) {
      // Check if dir is a valid plugin by trying to create a pluginInterface at that path
      PluginInterface tempPlugin;
      try {
        tempPlugin = PluginInterface(dir.path);
      } catch (e) {
        if (e
            .toString()
            .startsWith("Exception: Failed to load from config file:")) {
          // TODO: Show error to user and prompt user to uninstall plugin
          logger.e(e);
        } else {
          rethrow;
        }
        continue;
      }
      allPlugins.add(tempPlugin);
      if (enabledPluginsFromSettings.contains(tempPlugin.codeName)) {
        enabledPlugins.add(tempPlugin);
        // create a separate cache dir for each plugin and symlink it to the plugin dir
        Directory cacheDir = Directory("${cachePath.path}/plugins/${tempPlugin.codeName}");
        if (!cacheDir.existsSync()) {
          cacheDir.create(recursive: true);
          Link("${dir.path}/cache").createSync("${cachePath.path}/plugins/${tempPlugin.codeName}");
        }
      }
      if (enabledHomepageProvidersFromSettings.contains(tempPlugin.codeName)) {
        enabledHomepageProviders.add(tempPlugin);
      }
    }
  }

  static Future<void> writePluginListToSettings() async {
    List<String> settingsList = [];
    for (var plugin in allPlugins) {
      settingsList.add(plugin.codeName);
    }
    logger.d("Writing plugins list to settings");
    logger.d(settingsList);
    sharedStorage.setStringList('enabled_plugins', settingsList);
    // download plugin icons if they don't yet exist
    IconManager().downloadPluginIcons();
  }

  static Future<void> writeHomepageProvidersListToSettings() async {
    List<String> settingsList = [];
    for (var plugin in allPlugins) {
      settingsList.add(plugin.codeName);
    }
    logger.d("Writing Homepage providers list to settings");
    logger.d(settingsList);
    sharedStorage.setStringList('homepage_providers', settingsList);
    // download plugin icons if they don't yet exist
    IconManager().downloadPluginIcons();
  }

  static PluginInterface? getPluginByName(String name) {
    for (var plugin in allPlugins) {
      if (plugin.codeName == name) {
        return PluginInterface("${pluginsDir.path}/$plugin");
      }
    }
    logger.e("Didnt find plugin with name: $name");
    return null;
  }

  Future<Map<String, dynamic>> extractPlugin(
      FilePickerResult? pickedFile) async {
    try {
      // Create a temporary directory with random name to process the zip file
      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory("${tempDir.path}/extracted_plugin");
      logger.d("Deleting and recreating temp dir at ${outputDir.path}");
      if (outputDir.existsSync()) {
        outputDir.deleteSync(recursive: true);
      }
      await outputDir.create(recursive: true);

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
      if (allPlugins
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

    PluginManager.discoverAndLoadPlugins();

    return true;
  }
}
