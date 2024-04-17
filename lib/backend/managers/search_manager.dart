import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hedon_viewer/backend/managers/database_manager.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/plugin_base.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';

class SearchHandler {
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page,
      [List<PluginBase> providers = const []]) async {
    // TODO: Improve UX, by showing a fullscreen error and stopping the search
    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      return [];
    }

    // read providers from settings if not passed to this function
    if (providers.isEmpty) {
      providers = PluginManager.enabledPlugins;
      if (providers.isEmpty) {
        throw Exception("No providers provided or configured in settings");
      }
    }

    // After internet and provider check have passed, add request to search history
    DatabaseManager.addToSearchHistory(request, providers);

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

  // TODO: Add setting to chose search suggestion provider
  // TODO: Add setting to sort by alphabetical order
  Future<List<String>> getSearchSuggestions(String query) async {
    return PluginManager.getPluginByName(
            sharedStorage.getString("search_provider")!)!
        .getSearchSuggestions(query);
  }
}
