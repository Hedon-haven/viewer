import 'package:flutter/foundation.dart';

import '/utils/global_vars.dart';
import '/utils/plugin_interface.dart';
import '/official_plugins/pornhub.dart';
import '/official_plugins/tester.dart';
import '/official_plugins/xhamster.dart';

// While official plugins are also PluginInterface types, they in reality do not
// communicate with any binaries, but are compiled directly into the app

Future<PluginInterface?> getOfficialPluginByName(String codename) async {
  switch (codename) {
    case "tester-official":
      if (!(await sharedStorage.getBool("enable_dev_options"))!) {
        logger.e("Tester plugin requested in non-debug mode");
        throw Exception("Tester plugin requested in non-debug mode");
      }
      return TesterPlugin();
    case "pornhub-official":
      return PornhubPlugin();
    case "xhamster-official":
      return XHamsterPlugin();
    default:
      break;
  }
  return null;
}

Future<List<PluginInterface>> getAllOfficialPlugins() async {
  if ((await sharedStorage.getBool("enable_dev_options"))!) {
    return [TesterPlugin(), PornhubPlugin(), XHamsterPlugin()];
  } else {
    return [PornhubPlugin(), XHamsterPlugin()];
  }
}
