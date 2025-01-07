import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

import '/plugins/official_plugins/official_plugin_base.dart';
import '/utils/plugin_interface.dart';
import '/utils/universal_formats.dart';

/// This plugin is only used for testing and is hidden in the release version
class TesterPlugin extends PluginBase implements PluginInterface {
  @override
  bool isOfficialPlugin = true;
  @override
  String codeName = "tester-official";
  @override
  String prettyName = "Tester plugin";
  @override
  Uri iconUrl = Uri.parse("https://placehold.co/favicon.ico");
  @override
  String providerUrl = "https://tester-plugin.com";
  @override
  int initialHomePage = 0;
  @override
  int initialSearchPage = 0;
  @override
  int initialCommentsPage = 0;
  @override
  int initialVideoSuggestionsPage = 0;
  @override
  bool providesDownloads = true;
  @override
  bool providesHomepage = true;
  @override
  bool providesResults = true;
  @override
  bool providesSearchSuggestions = true;
  @override
  bool providesVideo = true;

  // The following fields are inherited from PluginInterface, but not needed due to this class not actually being an interface
  @override
  Uri? updateUrl;
  @override
  double version = 0.1;

  @override
  Future<List<UniversalVideoPreview>> getHomePage(int page) async {
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(seconds: 2));
    return List.generate(
      50,
      (index) => UniversalVideoPreview(
        videoID: "${(index * pi * 10000).toInt()}",
        title: "Test homepage video $index",
        plugin: this,
        thumbnail: "https://placehold.co/1280x720.png",
        previewVideo: Uri.parse(
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_2mb.mp4"),
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        author: "Tester-author $index",
        verifiedAuthor: index % 2 == 0,
      ),
    );
  }

  @override
  Future<List<UniversalVideoPreview>> getSearchResults(
      UniversalSearchRequest request, int page) async {
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(seconds: 2));
    return List.generate(
      50,
      (index) => UniversalVideoPreview(
        videoID: "${(index * pi * 10000).toInt()}",
        title: "Test result video $index",
        plugin: this,
        thumbnail: "https://placehold.co/1280x720.png",
        previewVideo: Uri.parse(
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_2mb.mp4"),
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        author: "Tester-author $index",
        verifiedAuthor: index % 2 == 0,
      ),
    );
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(String videoId) async {
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(seconds: 2));
    return UniversalVideoMetadata(
      videoID: videoId,
      m3u8Uris: {
        720: Uri.parse(
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_2mb.mp4"),
        480: Uri.parse(
            "https://sample-videos.com/video321/mp4/480/big_buck_bunny_480p_1mb.mp4"),
        240: Uri.parse(
            "https://sample-videos.com/video321/mp4/240/big_buck_bunny_240p_1mb.mp4"),
      },
      title: "Tester video metadata title",
      plugin: this,
      author: "Tester-author",
      authorID: "tester-author-$videoId",
      actors: ["Tester-actor-1", "Tester-actor-2"],
      description: "Tester video description",
      viewsTotal: 2532823,
      tags: ["Tester-tag-1", "Tester-tag-2"],
      categories: ["Tester-category-1", "Tester-category-2"],
      uploadDate: DateTime.now(),
      ratingsPositiveTotal: 90,
      ratingsNegativeTotal: 10,
      ratingsTotal: 47384,
      virtualReality: false,
      chapters: {
        Duration(seconds: 0): "Chapter 1",
        Duration(seconds: 120): "Chapter 2",
        Duration(seconds: 240): "Chapter 3",
      },
      rawHtml: Document(),
    );
  }

  @override
  Future<void> isolateGetProgressThumbnails(SendPort sendPort) async {
    // Receive data from the main isolate
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final message = await receivePort.first as List;
    final rootToken = message[0] as RootIsolateToken;
    final resultsPort = message[1] as SendPort;
    final rawHtml = message[3] as Document;

    // Not quite sure what this is needed for, but fails otherwise
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    List<Uint8List> completedProcessedImages = [];

    // convert placeholder image to Uint8List
    final response =
        await http.get(Uri.parse("https://placehold.co/720x480.png"));
    if (response.statusCode == 200) {
      for (int i = 0; i < 10; i++) {
        completedProcessedImages.add(response.bodyBytes);
      }
    } else {
      throw Exception("Failed to download/convert placeholder image");
    }

    resultsPort.send(completedProcessedImages);
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) async {
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(milliseconds: 200));
    return List.generate(10, (index) => "$searchString-$index");
  }

  @override
  Future<bool> initPlugin() {
    return Future.value(true);
  }

  @override
  bool runFunctionalityTest() {
    return true;
  }

  @override
  Future<List<UniversalComment>> getComments(
      String videoID, Document rawHtml, int page) async {
    if (page == 5) {
      return [];
    }
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(seconds: 2));
    return List.generate(
      5,
      (index) => UniversalComment(
        videoID: videoID,
        author: "author-$index",
        commentBody: List<String>.filled(5, "test comment $index ").join(),
        hidden: index % 4 == 0,
        plugin: this,
        authorID: "author-$index",
        commentID: "comment-$index",
        countryID: "US",
        orientation: null,
        profilePicture: "https://placehold.co/240x240.png",
        ratingsPositiveTotal: index % 4 == 0 ? 30 : null,
        ratingsNegativeTotal: index % 4 == 0 ? 2 : null,
        ratingsTotal: index % 4 == 0 ? 32 : 76,
        commentDate: DateTime.now().subtract(Duration(days: index)),
        replyComments: index % 2 == 0
            ? List.generate(
                3,
                (index) => UniversalComment(
                  videoID: videoID,
                  author: "author-reply-$index",
                  commentBody:
                      List<String>.filled(5, "test reply comment $index ")
                          .join(),
                  hidden: index % 4 == 0,
                  plugin: this,
                  authorID: "author-reply-$index",
                  commentID: "comment-reply-$index",
                  countryID: "US",
                  orientation: null,
                  profilePicture: "https://placehold.co/240x240",
                  ratingsPositiveTotal: index % 2 == 0 ? 4 : null,
                  ratingsNegativeTotal: index % 2 == 0 ? 1 : null,
                  ratingsTotal: index % 2 == 0 ? 5 : 6,
                  commentDate: DateTime.now().subtract(Duration(days: index)),
                  replyComments: [],
                ),
              )
            : [],
      ),
    );
  }

  @override
  Future<List<UniversalVideoPreview>> getVideoSuggestions(
      String videoID, Document rawHtml, int page) async {
    // Simulate a delay without blocking the entire app
    await Future.delayed(Duration(seconds: 2));
    return List.generate(
      50,
      (index) => UniversalVideoPreview(
        videoID: "${(index * pi * 10000).toInt()}",
        title: "Test suggestion video $index",
        plugin: this,
        thumbnail: "https://placehold.co/1280x720.png",
        previewVideo: Uri.parse(
            "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_2mb.mp4"),
        duration: Duration(seconds: 120 + index * 10),
        viewsTotal: (index * pi * 1000000).toInt(),
        ratingsPositivePercent:
            int.tryParse((index * pi * 10000).toStringAsFixed(2)) ?? 50,
        maxQuality: 720,
        virtualReality: false,
        author: "Tester-suggestion-author $index",
        verifiedAuthor: index % 2 == 0,
      ),
    );
  }
}
