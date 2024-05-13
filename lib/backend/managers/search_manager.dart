import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hedon_viewer/backend/managers/database_manager.dart';
import 'package:hedon_viewer/backend/managers/plugin_manager.dart';
import 'package:hedon_viewer/backend/plugin_base.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:hedon_viewer/main.dart';

class SearchHandler {
  Map<PluginBase, int> pluginPageCounter = {};

  /// Pass empty searchRequest to get Homepage results
  Future<List<UniversalSearchResult>> getResults(
      [UniversalSearchRequest? searchRequest,
      List<UniversalSearchResult>? previousResults,
      List<PluginBase> providers = const []]) async {
    List<UniversalSearchResult> combinedResults = [];
    if (previousResults != null) {
      combinedResults = previousResults;
    }

    // TODO: Improve UX, by showing a fullscreen error and stopping the search
    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      print("No internet connection, canceling search");
      return [];
    }

    // read providers from settings if not passed to this function
    if (providers.isEmpty) {
      if (searchRequest == null) {
        // if search request empty -> homepage request
        providers = PluginManager.enabledHomepageProviders;
      } else {
        providers = PluginManager.enabledPlugins;
      }
      if (providers.isEmpty) {
        throw Exception("No providers provided or configured in settings");
      }
    }

    if (searchRequest != null) {
      // After internet and provider check have passed, add request to search history
      DatabaseManager.addToSearchHistory(searchRequest, providers);
    }

    // if previousResults is empty -> new search -> populate pluginPageCounter
    if (previousResults == null) {
      print("No prev results, populating pluginPageCounter");
      for (var provider in providers) {
        pluginPageCounter[provider] = searchRequest == null
            ? provider.initialHomePage
            : provider.initialSearchPage;
      }
    }

    // search in all plugins and combine their lists into one big list
    // TODO: Look for equivalent videos on multiple platforms and combine them into one entity with multiple sources
    // TODO: Add result mixing (i.e. show one video from one provider, and one from another, instead of all from one, then all from another)
    // TODO: Add empty results error display
    for (var provider in providers) {
      if (pluginPageCounter[provider] != -1) {
        List<UniversalSearchResult> results = [];
        if (searchRequest == null) {
          print("Search request is null, getting homepage");
          results = await provider.getHomePage(pluginPageCounter[provider]!);
        } else {
          print("Search request is not null, getting search results");
          results = await provider.getSearchResults(
              searchRequest, pluginPageCounter[provider]!);
        }
        if (results.isNotEmpty) {
          combinedResults.addAll(results);
          pluginPageCounter[provider] = pluginPageCounter[provider]! + 1;
          print(
              "Got results from ${provider.pluginName} for page ${pluginPageCounter[provider]}");
        } else {
          print("No more results from ${provider.pluginName}");
          pluginPageCounter[provider] = -1;
        }
      }
    }
    print("Prev res amount: ${previousResults?.length}");
    print("New res amount: ${combinedResults.length}");
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
