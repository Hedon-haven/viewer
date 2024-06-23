import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

import '/backend/plugin_interface.dart';
import '/main.dart';
import 'plugin_manager.dart';

/// Including plugin images in the app itself (or inside the third party plugin) might break copyright law
/// -> download at first run and store locally
// TODO: Every n-th run redownload the images?
class IconManager {
  void downloadPluginIcons() async {
    logger.i("Downloading plugin icons");
    Directory cacheDir = await getApplicationCacheDirectory();
    for (PluginInterface plugin in PluginManager.enabledPlugins) {
      Response response = await http.get(plugin.iconUrl);
      if (response.statusCode == 200) {
        logger.d(
            "Saving icon for ${plugin.name} to ${cacheDir.path}/${plugin.name}");
        await File("${cacheDir.path}/${plugin.name}")
            .writeAsBytes(response.bodyBytes);
      } else {
        logger.w(
            "Error downloading icon: ${response.statusCode} - ${response.reasonPhrase}"
            "\nReplacing with default icon");
        // use unknown plugin instead of nothing
        await File("assets/unknown-plugin.png")
            .copy("${cacheDir.path}/${plugin.name}");
      }
    }
  }
}
