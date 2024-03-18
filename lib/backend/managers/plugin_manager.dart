import 'package:hedon_viewer/backend/plugin_base.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/plugins/xhamster.dart';

class PluginManager {
  // make the plugin manager a singleton.
  // This way any part of the app can access the plugins, without having to re-initialize them
  static final PluginManager _instance = PluginManager._init();

  PluginManager._init() {
    readPluginListFromSettings();
  }

  factory PluginManager() {
    return _instance;
  }

  // TODO: Find a better solution to keep track of official plugins
  // TODO: Dont initialize all plugins at startup
  static List<PluginBase> allPlugins = [XHamsterPlugin()];
  static List<PluginBase> enabledPlugins = [];

  static Future<void> readPluginListFromSettings() async {
    // read enabled plugins from settings
    List<String> newEnabledPlugins =
        sharedStorage.getStringList('enabled_plugins') ?? [];
    enabledPlugins = []; // clear already enabled plugins
    for (var plugin in allPlugins) {
      if (newEnabledPlugins.contains(plugin.pluginName)) {
        enabledPlugins.add(plugin);
      }
      print("Updated plugin list: $enabledPlugins");
    }
  }

  static Future<void> writePluginListToSettings() async {
    sharedStorage.setStringList(
        'enabled_plugins', enabledPlugins.map((e) => e.pluginName).toList());
  }

  static PluginBase? getPluginByName(String pluginName) {
    for (var plugin in allPlugins) {
      if (plugin.pluginName == pluginName) {
        return plugin;
      }
    }
    print("Didnt find plugin with name: $pluginName");
    return null;
  }
}
