import 'dart:io';

import 'package:hedon_viewer/backend/plugin_base.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

import 'plugin_manager.dart';

/// Including plugin images in the app itself (or inside the third party plugin) might break copyright law
/// -> download at first run and store locally
// TODO: Every n-th run redownload the images?
class IconManager {
  void downloadPluginIcons() async {
    print("Downloading plugin icons");
    Directory cacheDir = await getApplicationCacheDirectory();
    for (PluginBase plugin in PluginManager.allPlugins) {
      Response response = await http.get(plugin.pluginIconUri);
      if (response.statusCode == 200) {
        print(
            "Saving icon for ${plugin.pluginName} to ${cacheDir.path}/${plugin.pluginName}");
        await File("${cacheDir.path}/${plugin.pluginName}")
            .writeAsBytes(response.bodyBytes);
      } else {
        print(
            "Error downloading icon: ${response.statusCode} - ${response.reasonPhrase}");
        // use unknown plugin instead of nothing
        await File("assets/unknown-plugin.png")
            .copy("${cacheDir.path}/${plugin.pluginName}");
      }
    }
  }
}
