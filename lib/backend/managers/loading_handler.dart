import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:html/dom.dart';
import 'package:linkify/linkify.dart';

import '/backend/managers/database_manager.dart';
import '/backend/managers/plugin_manager.dart';
import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';

/// Handles various loading sections, including search and comments
class LoadingHandler {
  Map<PluginInterface, int> resultsPageCounter = {};
  int commentsPageCounter = 0;
  int videoSuggestionsPageCounter = 0;

  Future<void> clearVariables() async {
    resultsPageCounter = {};
    commentsPageCounter = 0;
    videoSuggestionsPageCounter = 0;
  }

  /// Pass empty searchRequest to get Homepage results
  Future<List<UniversalVideoPreview>?> getSearchResults(
      [UniversalSearchRequest? searchRequest,
      List<UniversalVideoPreview>? previousResults,
      List<PluginInterface> plugins = const []]) async {
    List<UniversalVideoPreview>? combinedResults = [];
    if (previousResults != null) {
      combinedResults = previousResults;
    }

    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling search");
      return null;
    } else {
      logger.d("Internet connection present");
    }

    // read plugins from settings if not passed to this function
    if (plugins.isEmpty) {
      if (searchRequest == null) {
        // if search request empty -> homepage request
        plugins = PluginManager.enabledHomepageProviders;
      } else {
        plugins = PluginManager.enabledResultsProviders;
      }
      // This should not happen
      if (plugins.isEmpty) {
        logger.e(
            "No results providers passed to function or configured in settings");
        return null;
      }
    }

    if (searchRequest != null) {
      // After internet and plugin check have passed, add request to search history
      addToSearchHistory(searchRequest, plugins);
    }

    // if previousResults is empty -> new search -> populate pluginPageCounter
    if (previousResults == null) {
      logger.i("No prev results, populating pluginPageCounter");
      for (var plugin in plugins) {
        resultsPageCounter[plugin] = searchRequest == null
            ? plugin.initialHomePage
            : plugin.initialSearchPage;
      }
    }

    // Search each plugin for results and store them in a map
    Map<String, List<UniversalVideoPreview>> pluginResults = {};
    for (var plugin in plugins) {
      if (resultsPageCounter[plugin] != -1) {
        List<UniversalVideoPreview>? results;
        if (searchRequest == null) {
          logger.i("Search request is null, getting homepage");
          try {
            results = await plugin.getHomePage(resultsPageCounter[plugin]!);
          } catch (e, stacktrace) {
            logger.e("Error getting homepage from ${plugin.codeName}: $e\n$stacktrace");
            results = null;
          }
        } else {
          logger.i("Search request is not null, getting search results");
          try {
            results = await plugin.getSearchResults(
                searchRequest, resultsPageCounter[plugin]!);
          } catch (e, stacktrace) {
            logger
                .e("Error getting search results from ${plugin.codeName}: $e\n$stacktrace");
            results = null;
          }
        }
        if (results?.isNotEmpty ?? false) {
          pluginResults[plugin.codeName] = results!;
          resultsPageCounter[plugin] = resultsPageCounter[plugin]! + 1;
          logger.i(
              "Got results from ${plugin.codeName} for page ${resultsPageCounter[plugin]}");
        } else if (results?.isEmpty ?? false) {
          if (previousResults == null) {
            logger.w("No results at all from ${plugin.codeName}");
          } else {
            logger.w("No more results from ${plugin.codeName}");
          }
          resultsPageCounter[plugin] = -1;
        }
      }
    }

    if (pluginResults.isEmpty) {
      logger.w("No results from any enabled providers");
      combinedResults = null;
    } else {
      // Combine individual plugin results into one list in a round-robin fashion
      bool resultsRemaining = true;
      int currentIndex = 0;
      while (resultsRemaining) {
        resultsRemaining = false;
        for (var plugin in plugins) {
          // Check if the plugin has results and if there is a result at the current index
          if (pluginResults.containsKey(plugin.codeName) &&
              pluginResults[plugin.codeName]!.length > currentIndex) {
            combinedResults.add(pluginResults[plugin.codeName]![currentIndex]);
            resultsRemaining = true;
          }
        }
        currentIndex++;
      }
    }

    logger.d("Prev res amount: ${previousResults?.length}");
    logger.d("New res amount: ${combinedResults?.length}");
    return combinedResults;
  }

  Future<List<UniversalSearchRequest>?> getSearchSuggestions(
      String query) async {
    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling search");
      return null;
    } else {
      logger.d("Internet connection present");
    }

    // check if there are any enabled search suggestions providers
    if (PluginManager.enabledSearchSuggestionsProviders.isEmpty) {
      logger.e("No search suggestions providers configured in settings");
      return null;
    }

    // Simultaneously start queries for all enabled plugins
    List<Future<List<String>>> futures = [];
    for (var plugin in PluginManager.enabledSearchSuggestionsProviders) {
      futures.add(plugin.getSearchSuggestions(query));
    }

    // Wait for all queries to finish
    List<List<String>?> allResults = [];
    for (var future in futures) {
      try {
        allResults.add(await future);
      } catch (e, stacktrace) {
        print("Failed to get search suggestions from a plugin: $e\n$stacktrace");
        allResults.add(null);
      }
    }

    // Check if all queries failed
    if (allResults.every((element) => element == null)) {
      logger.w("All search suggestion queries failed");
      return null;
    }

    // Count the frequency of each suggestion (case insensitive)
    Map<String, int> frequency = {};
    for (var list in allResults) {
      if (list == null) continue;
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
      if (allResults[i] == null) continue;
      for (var suggestion in allResults[i]!) {
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

    // Convert the list to a list of UniversalSearchRequests
    return finalList
        .map((s) => UniversalSearchRequest(searchString: s))
        .toList();
  }

  Future<List<UniversalComment>?> getCommentResults(
      PluginInterface plugin, String videoID, Document rawHtml,
      [List<UniversalComment>? previousResults]) async {
    List<UniversalComment>? combinedResults = [];
    if (previousResults != null) {
      combinedResults = previousResults;
    }

    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling comment request");
      return null;
    }

    // if previousResults is empty -> new search -> set pluginPageCounter
    if (previousResults == null) {
      commentsPageCounter = plugin.initialCommentsPage;
      logger.i(
          "No prev comment results, setting commentsPageCounter to $commentsPageCounter");
    }

    List<UniversalComment>? newResults;
    if (commentsPageCounter != -1) {
      logger.i(
          "Getting comments from ${plugin.codeName} for page $commentsPageCounter");
      try {
        newResults =
            await plugin.getComments(videoID, rawHtml, commentsPageCounter);
        logger.i(
            "Got ${newResults.length} comments from ${plugin.codeName} for page $commentsPageCounter");
      } catch (e, stacktrace) {
        logger.w("Error getting comments from ${plugin.codeName}: $e\n$stacktrace");
        newResults = null;
      }
      if (newResults?.isNotEmpty ?? false) {
        List<UniversalComment> filteredComments = [];
        for (var comment in newResults!) {
          if ((await sharedStorage.getBool("comments_hide_hidden"))!) {
            if (comment.hidden) {
              logger.d(
                  "Filtered comment: ${comment.commentID}; Cause: hidden by platform");
              continue;
            }
          } else if ((await sharedStorage.getBool("comments_hide_negative"))!) {
            if ((comment.ratingsNegativeTotal ?? 0) < 0) {
              logger.d(
                  "Filtered comment: ${comment.commentID}; Cause: negative rating");
              continue;
            }
          } else if ((await sharedStorage.getBool("comments_filter_links"))!) {
            if (linkify(comment.commentBody)
                .any((element) => element is LinkableElement)) {
              logger.d(
                  "Filtered comment: ${comment.commentID}; Cause: contains link");
              continue;
            }
          } else if ((await sharedStorage
              .getBool("comments_filter_non_ascii"))!) {
            // Unicode is a superset of ASCII
            // -> Unicode 0-127 is equivalent to ASCII
            if (comment.commentBody.runes.any((code) => code > 127)) {
              logger.d(
                  "Filtered comment: ${comment.commentID}; Cause: contains non-ascii text");
              continue;
            } else {
              logger.d("Did not filter: ${comment.commentID}");
            }
          }
          filteredComments.add(comment);
        }
        logger.d(
            "Filtered ${newResults.length - filteredComments.length} comments");
        newResults = filteredComments;

        combinedResults.addAll(newResults);
        logger.i("Added ${newResults.length} comments");
        commentsPageCounter++;
      } else if (newResults?.isEmpty ?? false) {
        if (previousResults == null) {
          logger.w("No comments found at all for $videoID");
        } else {
          logger.i("No more comments found for $videoID");
        }
        commentsPageCounter = -1;
      } else {
        // In case of error
        combinedResults = null;
      }
    }

    logger.d("Prev comment res amount: ${previousResults?.length}");
    logger.d("New comment res amount: ${combinedResults?.length}");
    return combinedResults;
  }

  Future<List<UniversalVideoPreview>?> getVideoSuggestions(
      PluginInterface plugin, String videoID, Document rawHtml,
      [List<UniversalVideoPreview>? previousResults]) async {
    List<UniversalVideoPreview>? combinedResults = [];
    if (previousResults != null) {
      combinedResults = previousResults;
    }

    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling video suggestions request");
      return [];
    }

    // if previousResults is empty -> new search -> set pluginPageCounter
    if (previousResults == null) {
      videoSuggestionsPageCounter = plugin.initialVideoSuggestionsPage;
      logger.i(
          "No prev video suggestions results, setting videoSuggestionsPageCounter to $videoSuggestionsPageCounter");
    }

    List<UniversalVideoPreview>? newResults;
    if (videoSuggestionsPageCounter != -1) {
      logger.i(
          "Getting video suggestions from ${plugin.codeName} for page $videoSuggestionsPageCounter");
      try {
        newResults = await plugin.getVideoSuggestions(
            videoID, rawHtml, videoSuggestionsPageCounter);
        logger.i(
            "Got ${newResults.length} video suggestions from ${plugin.codeName} for page $videoSuggestionsPageCounter");
      } catch (e, stacktrace) {
        logger.w("Error getting video suggestions from ${plugin.codeName}: $e\n$stacktrace");
      }
      if (newResults?.isNotEmpty ?? false) {
        combinedResults.addAll(newResults!);
        logger.i("Added ${newResults.length} video suggestions");
        videoSuggestionsPageCounter++;
      } else {
        if (newResults?.isEmpty ?? false) {
          if (previousResults == null) {
            logger.w("No video suggestions found at all for $videoID");
          } else {
            logger.i("No more video suggestions found for $videoID");
          }
        } else {
          // Error
          combinedResults = null;
        }
        videoSuggestionsPageCounter = -1;
      }
    }

    logger.d("Prev video suggestions amount: ${previousResults?.length}");
    logger.d("New video suggestions amount: ${combinedResults?.length}");
    return combinedResults;
  }
}
