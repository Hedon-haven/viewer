import 'package:connectivity_plus/connectivity_plus.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';

class SearchHandler {
  Map<PluginInterface, int> pluginPageCounter = {};

  /// Pass empty searchRequest to get Homepage results
  Future<List<UniversalSearchResult>> getResults(
      [UniversalSearchRequest? searchRequest,
      List<UniversalSearchResult>? previousResults,
      List<PluginInterface> plugins = const []]) async {
    List<UniversalSearchResult> combinedResults = [];
    if (previousResults != null) {
      combinedResults = previousResults;
    }

    // TODO: Improve UX, by showing a fullscreen error and stopping the search
    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling search");
      return [];
    }

    // read plugins from settings if not passed to this function
    if (plugins.isEmpty) {
      if (searchRequest == null) {
        // if search request empty -> homepage request
        plugins = PluginManager.enabledHomepageProviders;
      } else {
        plugins = PluginManager.enabledPlugins;
      }
      if (plugins.isEmpty) {
        throw Exception("No provider/plugins provided or configured in settings");
      }
    }

    if (searchRequest != null) {
      // After internet and plugin check have passed, add request to search history
      DatabaseManager.addToSearchHistory(searchRequest, plugins);
    }

    // if previousResults is empty -> new search -> populate pluginPageCounter
    if (previousResults == null) {
      logger.i("No prev results, populating pluginPageCounter");
      for (var plugin in plugins) {
        pluginPageCounter[plugin] = searchRequest == null
            ? plugin.initialHomePage
            : plugin.initialSearchPage;
      }
    }

    // search in all plugins and combine their lists into one big list
    // TODO: Look for equivalent videos on multiple platforms and combine them into one entity with multiple sources
    // TODO: Add result mixing (i.e. show one video from one plugin, and one from another, instead of all from one, then all from another)
    // TODO: Add empty results error display
    for (var plugin in plugins) {
      if (pluginPageCounter[plugin] != -1) {
        List<UniversalSearchResult> results = [];
        if (searchRequest == null) {
          logger.i("Search request is null, getting homepage");
          results = await plugin.getHomePage(pluginPageCounter[plugin]!);
        } else {
          logger.i("Search request is not null, getting search results");
          results = await plugin.getSearchResults(
              searchRequest, pluginPageCounter[plugin]!);
        }
        if (results.isNotEmpty) {
          combinedResults.addAll(results);
          pluginPageCounter[plugin] = pluginPageCounter[plugin]! + 1;
          logger.i(
              "Got results from ${plugin.name} for page ${pluginPageCounter[plugin]}");
        } else {
          logger.w("No more results from ${plugin.name}");
          pluginPageCounter[plugin] = -1;
        }
      }
    }
    logger.d("Prev res amount: ${previousResults?.length}");
    logger.d("New res amount: ${combinedResults.length}");
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
