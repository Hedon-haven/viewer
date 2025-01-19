import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedon_viewer/services/official_plugins_tracker.dart';
import 'package:hedon_viewer/utils/global_vars.dart';
import 'package:hedon_viewer/utils/official_plugin.dart';
import 'package:hedon_viewer/utils/plugin_interface.dart';
import 'package:hedon_viewer/utils/universal_formats.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';

// Keep in mind this import wont work until "flutter pub run build_runner build" is run
import 'utils/generate_mocks.mocks.dart';
import 'utils/testing_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init global values
  logger = Logger(printer: TestingPrinter());
  final mock = MockSharedPreferencesAsync();
  when(mock.getBool("enable_dev_options")).thenAnswer((_) async => false);
  sharedStorage = mock;

  // Read plugin name that should be tested from env
  String? pluginFromEnv = Platform.environment["PLUGIN"];

  if (pluginFromEnv == null) {
    logger.f("Couldn't read PLUGIN environment variable value");
    return;
  }

  PluginInterface? plugin = await getOfficialPluginByName(pluginFromEnv);
  if (plugin == null) {
    logger.f("Plugin with name $pluginFromEnv not found");
    return;
  }

  OfficialPlugin pluginAsOfficial =
      (await getOfficialPluginByNameAsOfficialPlugin(plugin.codeName))!;
  Map<String, dynamic> scrapedErrorsMap =
      pluginAsOfficial.testingMap["ignoreScrapedErrors"];
  List<Map<String, dynamic>> videosMap =
      pluginAsOfficial.testingMap["testingVideos"];

  group("Testing ${plugin.codeName}", () {
    test("initPlugin", () async {
      expect(await plugin.initPlugin(), equals(true));
    });

    group("getSearchSuggestions", () {
      List<String>? suggestions;
      setUpAll(() async {
        suggestions = await plugin.getSearchSuggestions("Art");
      });
      test("Make sure amount of returned result is greater than 0", () {
        expect(suggestions!.length, greaterThan(0));
      });
      test("Check at least one of the suggestions is \"Art\"", () {
        expect(suggestions!.contains("Art"), equals(true));
      });
    });

    group("getHomePage", () {
      List<UniversalVideoPreview> homepageResults = [];
      setUpAll(() async {
        // Get 3 pages of homepage
        homepageResults = [
          ...await plugin.getHomePage(plugin.initialHomePage),
          ...await plugin.getHomePage(plugin.initialHomePage + 1),
          ...await plugin.getHomePage(plugin.initialHomePage + 2)
        ];
      });
      test("Make sure amount of returned result is greater than 0", () {
        expect(homepageResults.length, greaterThan(0));
      });
      test("Check if all results were fully scraped", () {
        for (var result in homepageResults) {
          expect(
              result.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["homepage"]),
              equals(true));
        }
      });
    });

    group("getSearchResults", () {
      List<UniversalVideoPreview> searchResults = [];
      setUpAll(() async {
        // Getting 3 pages of search results for "Art"
        searchResults = [
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage),
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage + 1),
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage + 2)
        ];
      });
      test("Make sure amount of returned result is greater than 0", () {
        expect(searchResults.length, greaterThan(0));
      });
      test("Check if all results were fully scraped", () {
        for (var result in searchResults) {
          expect(
              result.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["searchResults"]),
              equals(true));
        }
      });
    });

    // The tests all need VideoMetadata -> scrape once to increase testing speed
    group("VideoMetadata tests", () {
      UniversalVideoMetadata? videoMetadataOne;
      UniversalVideoMetadata? videoMetadataTwo;
      setUpAll(() async {
        // Pass skeletons, a the uvp is only needed in ui tests
        videoMetadataOne = await plugin.getVideoMetadata(
            videosMap[0]["videoID"], UniversalVideoPreview.skeleton());
        videoMetadataTwo = await plugin.getVideoMetadata(
            videosMap[1]["videoID"], UniversalVideoPreview.skeleton());
      });

      group("getVideoMetadata", () {
        test(
            "Check if video metadata for ${videosMap[0]["videoID"]} was fully scraped",
            () {
          expect(
              videoMetadataOne!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["videoMetadata"]),
              equals(true));
        });
        test(
            "Check if video metadata for ${videosMap[1]["videoID"]} was fully scraped",
            () {
          expect(
              videoMetadataTwo!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["videoMetadata"]),
              equals(true));
        });
      });

      group("getVideoSuggestions", () {
        List<UniversalVideoPreview>? suggestionsOne;
        List<UniversalVideoPreview>? suggestionsTwo;
        setUpAll(() async {
          // Get 3 pages of video suggestions
          suggestionsOne = [
            ...await plugin.getVideoSuggestions(videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml, plugin.initialVideoSuggestionsPage),
            ...await plugin.getVideoSuggestions(
                videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml,
                plugin.initialVideoSuggestionsPage + 1),
            ...await plugin.getVideoSuggestions(
                videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml,
                plugin.initialVideoSuggestionsPage + 2)
          ];

          suggestionsTwo = [
            ...await plugin.getVideoSuggestions(videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml, plugin.initialVideoSuggestionsPage),
            ...await plugin.getVideoSuggestions(
                videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml,
                plugin.initialVideoSuggestionsPage + 1),
            ...await plugin.getVideoSuggestions(
                videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml,
                plugin.initialVideoSuggestionsPage + 2)
          ];
        });
        test(
            "Make sure amount of returned result is greater than 0 for ${videosMap[0]["videoID"]}",
            () {
          expect(suggestionsOne!.length, greaterThan(0));
        });
        test(
            "Make sure amount of returned result is greater than 0 for ${videosMap[1]["videoID"]}",
            () {
          expect(suggestionsTwo!.length, greaterThan(0));
        });
        test(
            "Check if all video suggestions for ${videosMap[0]["videoID"]} were fully scraped",
            () {
          for (var suggestion in suggestionsOne!) {
            expect(
                suggestion.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["videoSuggestions"]),
                equals(true));
          }
        });
        test(
            "Check if all video suggestions for ${videosMap[1]["videoID"]} were fully scraped",
            () {
          for (var suggestion in suggestionsTwo!) {
            expect(
                suggestion.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["videoSuggestions"]),
                equals(true));
          }
        });
      });

      group("getProgressThumbnails", () {
        List<Uint8List>? thumbnailsOne;
        List<Uint8List>? thumbnailsTwo;
        setUpAll(() async {
          thumbnailsOne = await plugin.getProgressThumbnails(
              videoMetadataOne!.videoID, videoMetadataOne!.rawHtml);
          thumbnailsTwo = await plugin.getProgressThumbnails(
              videoMetadataTwo!.videoID, videoMetadataTwo!.rawHtml);
        });
        test(
            "Check if ${videosMap[0]["progressThumbnailsAmount"]} progress thumbnails were scraped from ${videosMap[0]["videoID"]}",
            () {
          expect(thumbnailsOne!.length,
              equals(videosMap[0]["progressThumbnailsAmount"]));
        });
        test(
            "Check if ${videosMap[1]["progressThumbnailsAmount"]} progress thumbnails were scraped from ${videosMap[1]["videoID"]}",
            () {
          expect(thumbnailsTwo!.length,
              equals(videosMap[1]["progressThumbnailsAmount"]));
        });
      });

      group("getComments", () {
        List<UniversalComment>? commentsOne;
        List<UniversalComment>? commentsTwo;
        setUpAll(() async {
          // Get 3 pages of comments
          commentsOne = [
            ...await plugin.getComments(videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage),
            ...await plugin.getComments(videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage + 1),
            ...await plugin.getComments(videoMetadataOne!.videoID,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage + 2)
          ];

          commentsTwo = [
            ...await plugin.getComments(videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml, plugin.initialCommentsPage),
            ...await plugin.getComments(videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml, plugin.initialCommentsPage + 1),
            ...await plugin.getComments(videoMetadataTwo!.videoID,
                videoMetadataTwo!.rawHtml, plugin.initialCommentsPage + 2)
          ];
        });
        test(
            "Make sure amount of returned comments is greater than 0 for ${videosMap[0]["videoID"]}",
            () {
          expect(commentsOne!.length, greaterThan(0));
        });
        test(
            "Make sure amount of returned comments is greater than 0 for ${videosMap[1]["videoID"]}",
            () {
          expect(commentsTwo!.length, greaterThan(0));
        });
        test(
            "Check if all comments for ${videosMap[0]["videoID"]} were fully scraped",
            () {
          for (var comment in commentsOne!) {
            expect(
                comment.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["comments"]),
                equals(true));
          }
        });
        test(
            "Check if all comments for ${videosMap[1]["videoID"]} were fully scraped",
            () {
          for (var comment in commentsTwo!) {
            expect(
                comment.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["comments"]),
                equals(true));
          }
        });
      });
    });
  });
}
