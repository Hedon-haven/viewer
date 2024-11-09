import 'package:flutter/foundation.dart';

import '/backend/plugin_interface.dart';
import '/main.dart';
import 'official_plugins/pornhub.dart';
import 'official_plugins/tester.dart';
import 'official_plugins/xhamster.dart';

// While official plugins are also PluginInterface types, they in reality do not
// communicate with any binaries, but are compiled directly into the app

PluginInterface? getOfficialPluginByName(String name) {
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

List<PluginInterface> getAllOfficialPlugins() {
  if (kDebugMode || sharedStorage.getBool("enable_dev_options")!) {
    return [TesterPlugin(), PornhubPlugin(), XHamsterPlugin()];
  } else {
    return [PornhubPlugin(), XHamsterPlugin()];
  }
}
