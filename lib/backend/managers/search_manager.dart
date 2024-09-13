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
        plugins = PluginManager.enabledResultsProviders;
      }
      if (plugins.isEmpty) {
        throw Exception(
            "No results providers passed to function or configured in settings");
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
              "Got results from ${plugin.codeName} for page ${pluginPageCounter[plugin]}");
        } else {
          logger.w("No more results from ${plugin.codeName}");
          pluginPageCounter[plugin] = -1;
        }
      }
    }
    logger.d("Prev res amount: ${previousResults?.length}");
    logger.d("New res amount: ${combinedResults.length}");
    return combinedResults;
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    // TODO: Add error catching and automatically disable plugins with errors
    // Simultaneously start queries for all enabled plugins
    List<Future<List<String>>> futures = [];
    for (var plugin in PluginManager.enabledSearchSuggestionsProviders) {
      futures.add(plugin.getSearchSuggestions(query));
    }

    // Wait for all queries to finish
    List<List<String>> allResults = [];
    for (var future in futures) {
      allResults.add(await future);
    }

    // Count the frequency of each suggestion (case insensitive)
    Map<String, int> frequency = {};
    for (var list in allResults) {
      for (var suggestion in list) {
        String lowerSuggestion = suggestion.toLowerCase();
        frequency[lowerSuggestion] = (frequency[lowerSuggestion] ?? 0) + 1;
      }
    }

    // Separate singular suggestions from frequent ones
    List<String> frequentSuggestions = [];
    List<List<String>> singularSuggestions =
        List.generate(allResults.length, (_) => []);
    for (int i = 0; i < allResults.length; i++) {
      for (var suggestion in allResults[i]) {
        String lowerSuggestion = suggestion.toLowerCase();
        if (frequency[lowerSuggestion]! > 1) {
          if (!frequentSuggestions.contains(lowerSuggestion)) {
            frequentSuggestions.add(lowerSuggestion);
          }
        } else {
          singularSuggestions[i].add(lowerSuggestion);
        }
      }
    }

    // Sort frequent suggestions by frequency (most common first)
    frequentSuggestions.sort((a, b) => frequency[b]!.compareTo(frequency[a]!));

    // Interleave singular suggestions in round-robin fashion
    List<String> finalList = List.from(frequentSuggestions);
    bool singularsRemaining = true;
    int i = 0;
    while (singularsRemaining) {
      singularsRemaining = false;
      for (var list in singularSuggestions) {
        if (i < list.length) {
          finalList.add(list[i]);
          singularsRemaining = true;
        }
      }
      i++;
    }

    // Capitalize the first letter of each suggestion directly in the final list
    finalList =
        finalList.map((s) => s[0].toUpperCase() + s.substring(1)).toList();

    return finalList;
  }
}
