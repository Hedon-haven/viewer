import 'dart:io';

import 'package:hedon_viewer/backend/plugin_base.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

import 'plugin_manager.dart';

/// Including provider images in the app itself might break copyright law -> download at first run and store locally
// TODO: Every n-th run redownload the images?
class IconManager {
  void downloadProviderIcons() async {
    print("Downloading provider icons");
    Directory cacheDir = await getApplicationCacheDirectory();
    for (PluginBase provider in PluginManager.allPlugins) {
      Response response = await http.get(provider.pluginIconUri);
      if (response.statusCode == 200) {
        print(
            "Saving icon for ${provider.pluginName} to ${cacheDir.path}/${provider.pluginName}");
        await File("${cacheDir.path}/${provider.pluginName}")
            .writeAsBytes(response.bodyBytes);
      } else {
        print(
            "Error downloading icon: ${response.statusCode} - ${response.reasonPhrase}");
        // use unknown provider instead of nothing
        await File("assets/unknown-provider.png")
            .copy("${cacheDir.path}/${provider.pluginName}");
      }
    }
  }
}
