import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

import '/backend/plugin_interface.dart';
import '/main.dart';
import 'plugin_manager.dart';

/// Including plugin images in the app itself (or inside the third party plugin) might break copyright law
/// -> download at first run and store locally
// TODO: Every n-th run redownload the images instead of downloading every time
class IconManager {
  void downloadPluginIcons() async {
    logger.i("Downloading plugin icons");
    Directory sysCache = await getApplicationCacheDirectory();
    Directory cacheDir = Directory("${sysCache.path}/icons");
    // Create icon cache dir if it doesn't exist
    if (!cacheDir.existsSync()) {
      cacheDir.create();
    }
    for (PluginInterface plugin in PluginManager.enabledPlugins) {
      Response response = await http.get(plugin.iconUrl);
      if (response.statusCode == 200) {
        logger.d(
            "Saving icon for ${plugin.codeName} to ${cacheDir.path}/${plugin.codeName}");
        await File("${cacheDir.path}/${plugin.codeName}")
            .writeAsBytes(response.bodyBytes);
      } else {
        logger.w(
            "Error downloading icon: ${response.statusCode} - ${response.reasonPhrase}"
            "\nReplacing with default icon");
        // use unknown plugin instead of nothing
        await File("assets/unknown-plugin.png")
            .copy("${cacheDir.path}/${plugin.codeName}");
      }
    }
  }
}
