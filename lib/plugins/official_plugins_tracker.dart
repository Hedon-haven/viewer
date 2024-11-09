import 'package:flutter/foundation.dart';

import '/backend/plugin_interface.dart';
import '/main.dart';
import 'official_plugins/pornhub.dart';
import 'official_plugins/tester.dart';
import 'official_plugins/xhamster.dart';

// While official plugins are also PluginInterface types, they in reality do not
// communicate with any binaries, but are just directly implemented
// Due to not being a third party plugin, they are not stored anywhere on the users device, but are compiled directly into the app
class OfficialPluginsTracker {
  /// Get an official Plugin (as Interface) by provider name
  static PluginInterface? getPluginByName(String name) {
    switch (name) {
      case "Tester plugin":
        if (!kDebugMode || !sharedStorage.getBool("enable_dev_options")!) {
          logger.e("Tester plugin requested in non-debug mode");
          throw Exception("Tester plugin requested in non-debug mode");
        }
        return TesterPlugin();
      case "Pornhub.com":
        return PornhubPlugin();
      case "xHamster.com":
        return XHamsterPlugin();
      default:
        break;
    }
    return null;
  }

  static List<PluginInterface> getAllPlugins() {
    if (kDebugMode || sharedStorage.getBool("enable_dev_options")!) {
      return [TesterPlugin(), PornhubPlugin(), XHamsterPlugin()];
    } else {
      return [PornhubPlugin(), XHamsterPlugin()];
    }
  }
}
