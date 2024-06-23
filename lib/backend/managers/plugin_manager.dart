import 'dart:io';

import 'package:path_provider/path_provider.dart';

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

  /// Discover all plugins and loading according to settings in sharedStorage
  static Future<void> discoverAndLoadPlugins() async {
    // Set pluginsDir if not already set
    if (pluginsDir.path.isEmpty) {
      // set pluginPath for the whole manager
      Directory appSupportDir = await getApplicationSupportDirectory();
      pluginsDir = Directory("${appSupportDir.path}/plugins");
    }

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
      if (enabledPluginsFromSettings.contains(plugin.name)) {
        enabledPlugins.add(plugin);
      }
      if (enabledHomepageProvidersFromSettings.contains(plugin.name)) {
        enabledHomepageProviders.add(plugin);
      }
    }

    // If pluginsDir doesn't exist, no need to check for plugins inside it
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
      if (enabledPluginsFromSettings.contains(tempPlugin.name)) {
        enabledPlugins.add(tempPlugin);
      }
      if (enabledHomepageProvidersFromSettings.contains(tempPlugin.name)) {
        enabledHomepageProviders.add(tempPlugin);
      }
    }
  }

  static Future<void> writePluginListToSettings() async {
    List<String> settingsList = [];
    for (var plugin in allPlugins) {
      settingsList.add(plugin.name);
    }
    logger.d("Writing plugins list to settings");
    logger.d(settingsList);
    sharedStorage.setStringList('enabled_plugins', settingsList);
  }

  static Future<void> writeHomepageProvidersListToSettings() async {
    List<String> settingsList = [];
    for (var plugin in allPlugins) {
      settingsList.add(plugin.name);
    }
    logger.d("Writing Homepage providers list to settings");
    logger.d(settingsList);
    sharedStorage.setStringList('homepage_providers', settingsList);
  }

  static PluginInterface? getPluginByName(String name) {
    for (var plugin in allPlugins) {
      if (plugin.name == name) {
        return PluginInterface("${pluginsDir.path}/$plugin");
      }
    }
    logger.e("Didnt find plugin with name: $name");
    return null;
  }
}
