import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/plugins/xhamster.dart';

class PluginManager {
  // make the plugin manager a singleton.
  // This way any part of the app can access the plugins, without having to re-initialize them
  static final PluginManager _instance = PluginManager._init();

  PluginManager._init() {
    updatePluginListFromSettings();
  }

  factory PluginManager() {
    return _instance;
  }

  // TODO: Find a better solution to keep track of official plugins
  // TODO: Dont initialize all plugins at startup
  static List<PluginBase> allPlugins = [XHamsterPlugin()];
  static List<PluginBase> enabledPlugins = [];

  static Future<void> updatePluginListFromSettings() async {
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
}
