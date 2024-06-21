import 'package:hedon_viewer/backend/plugin_interface.dart';

import 'official_plugins/pornhub.dart';
import 'official_plugins/xhamster.dart';

// While official plugins are also PluginInterface types, they in reality do not
// communicate with any binaries, but are just directly implemented
// Due to not being a third party plugin, they are not stored anywhere on the users device, but are compiled directly into the app
class OfficialPluginsTracker {
  /// Get an official Plugin (as Interface) by provider name
  PluginInterface? getPluginByName(String name) {
    switch (name) {
      case "Pornhub.com":
        return PornhubPlugin();
      case "xHamster.com":
        return XHamsterPlugin();
      default:
        break;
    }
    return null;
  }

  List<PluginInterface> getAllPlugins() {
    return [PornhubPlugin(), XHamsterPlugin()];
  }
}
