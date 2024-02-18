import 'package:hedon_viewer/backend/plugin_manager.dart';
import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../base/universal_formats.dart';

class SearchHandler {
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page,
      [List<PluginBase> providers = const []]) async {
    // read providers from settings if not passed to this function
    if (providers.isEmpty) {
      providers = PluginManager.enabledPlugins;
      if (providers.isEmpty) {
        throw Exception("No providers provided or configured in settings");
      }
    }
    // search in all plugins and combine their lists into one big list
    // TODO: Look for equivalent videos on multiple platforms and combine them into one entity with multiple sources
    // TODO: Add result mixing (i.e. show one video from one provider, and one from another, instead of all from one, then all from another)
    // TODO: Add empty results error display
    List<UniversalSearchResult> combinedResults = [];
    for (var provider in providers) {
      combinedResults.addAll(await provider.search(request, page));
    }
    return combinedResults;
  }
}
