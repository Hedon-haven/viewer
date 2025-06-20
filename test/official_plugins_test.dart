import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedon_viewer/services/http_manager.dart';
import 'package:hedon_viewer/services/official_plugins_tracker.dart';
import 'package:hedon_viewer/utils/global_vars.dart';
import 'package:hedon_viewer/utils/official_plugin.dart';
import 'package:hedon_viewer/utils/plugin_interface.dart';
import 'package:hedon_viewer/utils/universal_formats.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';

// Keep in mind this import wont work until "flutter pub run build_runner build" is run
import 'utils/generate_mocks.mocks.dart';
import 'utils/testing_logger.dart';

Directory dumpDir = Directory("");

void debugCallback(String body, String functionName) {
  File("${dumpDir.path}/${functionName}_rawHtml.html").writeAsStringSync(body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init global values
  logger = Logger(printer: TestingPrinter());
  client = getHttpClient(null);
  final mock = MockSharedPreferencesAsync();
  when(mock.getBool("general_enable_dev_options"))
      .thenAnswer((_) async => false);
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
  List<String> authorPageIds =
      pluginAsOfficial.testingMap["testingAuthorPageIds"];

  // Create dump dir
  dumpDir = Directory("${Directory.current.path}/dumps");
  dumpDir.createSync(recursive: true);
  logger.i("Dump dir created at ${dumpDir.path}");

  // Create encoder with indent for nicer dumps
  JsonEncoder encoder = JsonEncoder.withIndent("  ");

  group("Testing ${plugin.codeName}", () {
    test("initPlugin", () async {
      expect(await plugin.initPlugin(), isTrue);
    });

    group("iconUrl", () {
      http.Response? response;
      test("Make sure iconUrl is valid and decodable", () async {
        // Fetch the .ico file
        response = await client.get(plugin.iconUrl);
        expect(response!.statusCode, 200);

        // Try to decode the image using the image package (supports various formats)
        final imageBytes = response!.bodyBytes;
        expect(imageBytes.isNotEmpty, isTrue);
        try {
          final decodedImage = decodeImage(Uint8List.fromList(imageBytes));
          expect(decodedImage, isNotNull);
        } catch (e) {
          fail("Failed to decode image: $e");
        }
      });
      tearDownAll(() {
        logger.i(
            "Dumping iconUrl to file (Warning, might not be actually an ico)");
        File("${dumpDir.path}/iconUrl.ico")
            .writeAsBytesSync(response!.bodyBytes);
      });
    });

    group("getSearchSuggestions", () {
      List<String>? suggestions;
      setUpAll(() async {
        suggestions = await plugin.getSearchSuggestions("Compil");
      });
      test("Make sure amount of returned result is greater than 0", () {
        expect(suggestions!.length, greaterThan(0));
      });
      test("Check at least one of the suggestions is \"Compilation\"", () {
        expect(suggestions!.contains("Compilation"), isTrue);
      });
      tearDownAll(() {
        logger.i("Dumping suggestions to file");
        File("${dumpDir.path}/getSearchSuggestions.json")
            .writeAsStringSync(encoder.convert(suggestions));
      });
    });

    group("getHomePage", () {
      List<UniversalVideoPreview> homepageResults = [];
      setUpAll(() async {
        // Get 3 pages of homepage
        homepageResults = [
          ...await plugin.getHomePage(plugin.initialHomePage, debugCallback),
          ...await plugin.getHomePage(
              plugin.initialHomePage + 1, debugCallback),
          ...await plugin.getHomePage(plugin.initialHomePage + 2, debugCallback)
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
              isTrue);
        }
      });
      tearDownAll(() {
        logger.i("Dumping getHomePage to file.");
        List<Map<String, dynamic>> homepageResultsAsMap =
            homepageResults.map((e) => e.toMap()).toList();
        File("${dumpDir.path}/getHomePage.json")
            .writeAsStringSync(encoder.convert(homepageResultsAsMap));
      });
    });

    group("getSearchResults", () {
      List<UniversalVideoPreview> searchResults = [];
      setUpAll(() async {
        // Getting 3 pages of search results for "Art"
        searchResults = [
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage,
              debugCallback),
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage + 1,
              debugCallback),
          ...await plugin.getSearchResults(
              UniversalSearchRequest(searchString: "Art"),
              plugin.initialSearchPage + 2,
              debugCallback)
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
              isTrue);
        }
      });
      tearDownAll(() {
        logger.i("Dumping getSearchResults to file.");
        List<Map<String, dynamic>> searchResultsAsMap =
            searchResults.map((e) => e.toMap()).toList();
        File("${dumpDir.path}/getSearchResults.json")
            .writeAsStringSync(encoder.convert(searchResultsAsMap));
      });
    });

    // The tests all need VideoMetadata -> scrape once to increase testing speed
    group("VideoMetadata tests", () {
      UniversalVideoMetadata? videoMetadataOne;
      UniversalVideoMetadata? videoMetadataTwo;
      setUpAll(() async {
        // Pass skeletons, a the uvp is only needed in ui tests
        videoMetadataOne = await plugin.getVideoMetadata(
            videosMap[0]["videoID"],
            UniversalVideoPreview.skeleton(),
            debugCallback);
        videoMetadataTwo = await plugin.getVideoMetadata(
            videosMap[1]["videoID"],
            UniversalVideoPreview.skeleton(),
            debugCallback);
      });

      group("getVideoMetadata", () {
        test(
            "Check if video metadata for ${videosMap[0]["videoID"]} was fully scraped",
            () {
          expect(
              videoMetadataOne!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["videoMetadata"]),
              isTrue);
        });
        test(
            "Check if video metadata for ${videosMap[1]["videoID"]} was fully scraped",
            () {
          expect(
              videoMetadataTwo!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["videoMetadata"]),
              isTrue);
        });
        tearDownAll(() {
          logger.i("Dumping getVideoMetadata to files.s "
              "in case of complete failure");
          File("${dumpDir.path}/getVideoMetadata_${videosMap[0]["videoID"]}.json")
              .writeAsStringSync(encoder.convert(videoMetadataOne!.toMap()));
          File("${dumpDir.path}/getVideoMetadata_${videosMap[1]["videoID"]}.json")
              .writeAsStringSync(encoder.convert(videoMetadataTwo!.toMap()));
          // Write htmls to file
          File("${dumpDir.path}/getVideoMetadata_${videosMap[0]["videoID"]}_rawHtml.html")
              .writeAsStringSync(videoMetadataOne!.rawHtml.outerHtml);
          File("${dumpDir.path}/getVideoMetadata_${videosMap[1]["videoID"]}_rawHtml.html")
              .writeAsStringSync(videoMetadataTwo!.rawHtml.outerHtml);
        });
      });

      group("getVideoSuggestions", () {
        List<UniversalVideoPreview>? suggestionsOne;
        List<UniversalVideoPreview>? suggestionsTwo;
        setUpAll(() async {
          // Get 3 pages of video suggestions
          suggestionsOne = [
            ...await plugin.getVideoSuggestions(videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml, plugin.initialVideoSuggestionsPage),
            ...await plugin.getVideoSuggestions(
                videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml,
                plugin.initialVideoSuggestionsPage + 1),
            ...await plugin.getVideoSuggestions(
                videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml,
                plugin.initialVideoSuggestionsPage + 2)
          ];

          suggestionsTwo = [
            ...await plugin.getVideoSuggestions(videoMetadataTwo!.iD,
                videoMetadataTwo!.rawHtml, plugin.initialVideoSuggestionsPage),
            ...await plugin.getVideoSuggestions(
                videoMetadataTwo!.iD,
                videoMetadataTwo!.rawHtml,
                plugin.initialVideoSuggestionsPage + 1),
            ...await plugin.getVideoSuggestions(
                videoMetadataTwo!.iD,
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
                isTrue);
          }
        });
        test(
            "Check if all video suggestions for ${videosMap[1]["videoID"]} were fully scraped",
            () {
          for (var suggestion in suggestionsTwo!) {
            expect(
                suggestion.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["videoSuggestions"]),
                isTrue);
          }
        });
        tearDownAll(() {
          logger.i("Dumping getVideoSuggestions to files");
          File("${dumpDir.path}/getVideoSuggestions_${videosMap[0]["videoID"]}.json")
              .writeAsStringSync(encoder
                  .convert(suggestionsOne!.map((e) => e.toMap()).toList()));
          File("${dumpDir.path}/getVideoSuggestions_${videosMap[1]["videoID"]}.json")
              .writeAsStringSync(encoder
                  .convert(suggestionsTwo!.map((e) => e.toMap()).toList()));
        });
      });

      group("getProgressThumbnails", () {
        List<Uint8List>? thumbnailsOne;
        List<Uint8List>? thumbnailsTwo;
        setUpAll(() async {
          thumbnailsOne = await plugin.getProgressThumbnails(
              videoMetadataOne!.iD, videoMetadataOne!.rawHtml);
          thumbnailsTwo = await plugin.getProgressThumbnails(
              videoMetadataTwo!.iD, videoMetadataTwo!.rawHtml);
        });
        test(
            "Check if ${videosMap[0]["progressThumbnailsAmount"]} progress thumbnails were scraped from ${videosMap[0]["videoID"]}",
            () {
          expect(
              thumbnailsOne!.length, videosMap[0]["progressThumbnailsAmount"]);
        });
        test(
            "Check if ${videosMap[1]["progressThumbnailsAmount"]} progress thumbnails were scraped from ${videosMap[1]["videoID"]}",
            () {
          expect(
              thumbnailsTwo!.length, videosMap[1]["progressThumbnailsAmount"]);
        });
        tearDownAll(() {
          logger.i(
              "Dumping each getProgressThumbnails thumbnail to separate file");
          // Create separate dir for each thumbnail list
          Directory(
                  "${dumpDir.path}/getProgressThumbnails_${videosMap[0]["videoID"]}")
              .createSync();
          Directory(
                  "${dumpDir.path}/getProgressThumbnails_${videosMap[1]["videoID"]}")
              .createSync();
          for (int i = 0; i < thumbnailsOne!.length; i++) {
            File("${dumpDir.path}/getProgressThumbnails_${videosMap[0]["videoID"]}/$i.jpeg")
                .writeAsBytesSync(thumbnailsOne![i]);
          }
          for (int i = 0; i < thumbnailsTwo!.length; i++) {
            File("${dumpDir.path}/getProgressThumbnails_${videosMap[1]["videoID"]}/$i.jpeg")
                .writeAsBytesSync(thumbnailsTwo![i]);
          }
        });
      });

      group("getComments", () {
        List<UniversalComment>? commentsOne;
        List<UniversalComment>? commentsTwo;
        setUpAll(() async {
          // Get 3 pages of comments
          commentsOne = [
            ...await plugin.getComments(videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage),
            ...await plugin.getComments(videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage + 1),
            ...await plugin.getComments(videoMetadataOne!.iD,
                videoMetadataOne!.rawHtml, plugin.initialCommentsPage + 2)
          ];

          commentsTwo = [
            ...await plugin.getComments(videoMetadataTwo!.iD,
                videoMetadataTwo!.rawHtml, plugin.initialCommentsPage),
            ...await plugin.getComments(videoMetadataTwo!.iD,
                videoMetadataTwo!.rawHtml, plugin.initialCommentsPage + 1),
            ...await plugin.getComments(videoMetadataTwo!.iD,
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
                isTrue);
          }
        });
        test(
            "Check if all comments for ${videosMap[1]["videoID"]} were fully scraped",
            () {
          for (var comment in commentsTwo!) {
            expect(
                comment.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["comments"]),
                isTrue);
          }
        });
        tearDownAll(() {
          logger.i("Dumping getComments to files");
          File("${dumpDir.path}/getComments_${videosMap[0]["videoID"]}.json")
              .writeAsStringSync(
                  encoder.convert(commentsOne!.map((e) => e.toMap()).toList()));
          File("${dumpDir.path}/getComments_${videosMap[1]["videoID"]}.json")
              .writeAsStringSync(
                  encoder.convert(commentsTwo!.map((e) => e.toMap()).toList()));
        });
      });
    });

    group("AuthorPage tests", () {
      // Some websites have 3 different author pages
      UniversalAuthorPage? authorPageOne;
      UniversalAuthorPage? authorPageTwo;
      UniversalAuthorPage? authorPageThree;
      setUpAll(() async {
        authorPageOne = await plugin.getAuthorPage(authorPageIds[0]);
        authorPageTwo = await plugin.getAuthorPage(authorPageIds[1]);
        authorPageThree = await plugin.getAuthorPage(authorPageIds[2]);
      });

      group("getAuthorPage", () {
        test(
            "Check if authorPage metadata for ${authorPageIds[0]} was fully scraped",
            () {
          expect(
              authorPageOne!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["authorPage"]),
              isTrue);
        });
        test(
            "Check if authorPage metadata for ${authorPageIds[1]} was fully scraped",
            () {
          expect(
              authorPageTwo!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["authorPage"]),
              isTrue);
        });
        test(
            "Check if authorPage metadata for ${authorPageIds[2]} was fully scraped",
            () {
          expect(
              authorPageThree!.verifyScrapedData(
                  plugin.codeName, scrapedErrorsMap["authorPage"]),
              isTrue);
        });
        tearDownAll(() {
          logger
              .i("Dumping getAuthorPage to files in case of complete failure");
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[0]}.json")
              .writeAsStringSync(encoder.convert(authorPageOne!.toMap()));
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[1]}.json")
              .writeAsStringSync(encoder.convert(authorPageOne!.toMap()));
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[2]}.json")
              .writeAsStringSync(encoder.convert(authorPageOne!.toMap()));
          // Write htmls to file
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[0]}_rawHtml.html")
              .writeAsStringSync(authorPageOne!.rawHtml.outerHtml);
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[1]}_rawHtml.html")
              .writeAsStringSync(authorPageOne!.rawHtml.outerHtml);
          File("${dumpDir.path}/getAuthorPage_${authorPageIds[2]}_rawHtml.html")
              .writeAsStringSync(authorPageOne!.rawHtml.outerHtml);
        });
      });
      group("getAuthorVideos", () {
        List<UniversalVideoPreview>? authorVideosOne;
        List<UniversalVideoPreview>? authorVideosTwo;
        List<UniversalVideoPreview>? authorVideosThree;
        setUpAll(() async {
          // Get 3 pages of video suggestions
          authorVideosOne = [
            ...await plugin.getAuthorVideos(
                authorPageOne!.iD, plugin.initialAuthorVideosPage),
            ...await plugin.getAuthorVideos(
                authorPageOne!.iD, plugin.initialAuthorVideosPage + 1),
            ...await plugin.getAuthorVideos(
                authorPageOne!.iD, plugin.initialAuthorVideosPage + 2)
          ];
          authorVideosTwo = [
            ...await plugin.getAuthorVideos(
                authorPageTwo!.iD, plugin.initialAuthorVideosPage),
            ...await plugin.getAuthorVideos(
                authorPageTwo!.iD, plugin.initialAuthorVideosPage + 1),
            ...await plugin.getAuthorVideos(
                authorPageTwo!.iD, plugin.initialAuthorVideosPage + 2)
          ];
          authorVideosThree = [
            ...await plugin.getAuthorVideos(
                authorPageThree!.iD, plugin.initialAuthorVideosPage),
            ...await plugin.getAuthorVideos(
                authorPageThree!.iD, plugin.initialAuthorVideosPage + 1),
            ...await plugin.getAuthorVideos(
                authorPageThree!.iD, plugin.initialAuthorVideosPage + 2)
          ];
        });
        test(
            "Make sure amount of returned results is greater than 0 for ${authorPageIds[0]}",
            () {
          expect(authorVideosOne!.length, greaterThan(0));
        });
        test(
            "Make sure amount of returned results is greater than 0 for ${authorPageIds[1]}",
            () {
          expect(authorVideosTwo!.length, greaterThan(0));
        });
        test(
            "Make sure amount of returned results is greater than 0 for ${authorPageIds[2]}",
            () {
          expect(authorVideosThree!.length, greaterThan(0));
        });
        test(
            "Check if all author videos for ${authorPageIds[0]} were fully scraped",
            () {
          for (var video in authorVideosOne!) {
            expect(
                video.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["authorVideos"]),
                isTrue);
          }
        });
        test(
            "Check if all author videos for ${authorPageIds[1]} were fully scraped",
            () {
          for (var video in authorVideosTwo!) {
            expect(
                video.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["authorVideos"]),
                isTrue);
          }
        });
        test(
            "Check if all author videos for ${authorPageIds[2]} were fully scraped",
            () {
          for (var video in authorVideosThree!) {
            expect(
                video.verifyScrapedData(
                    plugin.codeName, scrapedErrorsMap["authorVideos"]),
                isTrue);
          }
        });
        tearDownAll(() {
          logger.i("Dumping getAuthorVideos to files");
          File("${dumpDir.path}/getAuthorVideos_${authorPageIds[0]}.json")
              .writeAsStringSync(encoder
                  .convert(authorVideosOne!.map((e) => e.toMap()).toList()));
          File("${dumpDir.path}/getAuthorVideos_${authorPageIds[1]}.json")
              .writeAsStringSync(encoder
                  .convert(authorVideosTwo!.map((e) => e.toMap()).toList()));
          File("${dumpDir.path}/getAuthorVideos_${authorPageIds[2]}.json")
              .writeAsStringSync(encoder
                  .convert(authorVideosThree!.map((e) => e.toMap()).toList()));
        });
      });
    });
  });
}
