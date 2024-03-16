import 'package:hedon_viewer/backend/plugin_manager.dart';
import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/plugins/xhamster.dart';
import 'package:hedon_viewer/plugins/pornhub.dart';

void main() async {
  print("Starting tests");
  print("Testing if all plugins can load");
  try {
    for (PluginBase plugin in PluginManager.allPlugins) {
      print(plugin.pluginName);
    }
  } catch (e) {
    print(e);
  }

  print("Tesing plugins");
  List<UniversalSearchResult> asd = await XHamsterPlugin().search(UniversalSearchRequest(searchString: "xhWEGdf"), 1);

}
