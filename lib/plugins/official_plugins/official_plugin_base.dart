import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

import '/main.dart';
import '/backend/universal_formats.dart';

abstract class PluginBase {
  // the following strings are used by share/open in browser buttons throughout the app
  String videoEndpoint = "";
  String searchEndpoint = "";

  /// Initial page number
  // Some sites start at 0, some at 1
  // 0 is usually the same as the homepage from pluginURL
  int initialHomePage = 0;
  int initialSearchPage = 0;

  /// Contains cookies for the current session, usually filled by initPlugin()
  Map<String, String> sessionCookies = {};

  // Names maps
  /// Takes UniversalSearchRequest.sortingType and returns the string arg accepted by the provider in the url
  Map<String, String> sortingTypeMap = {};
  /// Takes UniversalSearchRequest.dateRange and returns the string arg accepted by the provider in the url
  Map<String, String> dateRangeMap = {};
  /// Takes UniversalSearchRequest.durationMin and returns the string arg accepted by the provider in the url
  Map<int, String> minDurationMap = {};
  /// Takes UniversalSearchRequest.durationMax and returns the string arg accepted by the provider in the url
  Map<int, String> maxDurationMap = {};

  /// Return the homepage
  Future<List<UniversalSearchResult>> getHomePage(int page);

  /// Return list of search results
  Future<List<UniversalSearchResult>> getSearchResults(
      UniversalSearchRequest request, int page);

  /// Request video metadata and convert it to UniversalFormat
  Future<UniversalVideoMetadata> getVideoMetadata(String videoId);

  /// As downloading thumbnails is relatively heavy (usually consists of downloading and cutting the image)
  /// it should run as an isolate.
  /// DO NOT OVERRIDE THIS FUNCTION
  Future<List<Uint8List>> getProgressThumbnails(String videoID, Document rawHtml) async {
    // spawn the isolate
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(isolateGetProgressThumbnails, receivePort.sendPort);
    final SendPort sendPort = await receivePort.first as SendPort;

    // pass the arguments
    final resultsPort = ReceivePort(); // for receiving the results
    logger.d("Sending arguments to isolate process");
    sendPort.send([videoID, rawHtml, resultsPort.sendPort]);

    // Wait for the results
    final List<Uint8List> thumbnails = await resultsPort.first as List<Uint8List>;
    logger.d("Received ${thumbnails.length} thumbnails from isolate process");
    // Cleanup
    receivePort.close();
    isolate.kill(priority: Isolate.immediate);
    return thumbnails;
  }

  /// Get all progressThumbnails for a video and return them as a List
  /// Keep in mind that this is an isolate function
  Future<void> isolateGetProgressThumbnails(SendPort sendPort);

  // Use this function instead of reimplementing it in plugins, as this function is able to handle errors properly
  /// download and parse json
  Future<Map> requestJson(Uri uri) async {
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      displayError(
          "Error downloading json: ${response.statusCode} - ${response.reasonPhrase}");
      return {};
    }
  }

  // Generally there is no need to override this rather simple function.
  /// This function returns the request thumbnail as a blob
  Future<Uint8List> downloadThumbnail(Uri uri) async {
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      displayError(
          "Error downloading preview: ${response.statusCode} - ${response.reasonPhrase}");
      return Uint8List(0);
    }
  }

  /// Parse a master m3u8 into media m3u8s
  Future<Map<int, Uri>> parseM3U8(Uri playListUri) async {
    Map<int, Uri> playListMap = {};
    // download and convert the m3u8 into a string
    var response = await http.get(playListUri);
    if (response.statusCode == 200) {
      String contentString = response.body;
      HlsMasterPlaylist? playList = (await HlsPlaylistParser.create()
          .parseString(playListUri, contentString)) as HlsMasterPlaylist?;

      // verify the playList is not empty
      if (playList != null) {
        for (var variant in playList.variants) {
          if (variant.format.height != null) {
            playListMap[variant.format.height!] = variant.url;
          } else {
            displayError("Error parsing m3u8: $playListUri");
          }
        }
      } else {
        displayError("M3U8 is empty??: $playListUri");
      }
    } else {
      displayError(
          "Error downloading m3u8 master file: ${response.statusCode} - ${response.reasonPhrase}");
    }
    return playListMap;
  }

  // Use this function instead of reimplementing it in plugins, as this function is able to handle errors properly
  /// download and parse html
  Future<Document> requestHtml(String uri) async {
    logger.i("requesting $uri");
    var response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      return parse(response.body);
    } else {
      displayError(
          "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}: $uri");
      return parse("");
    }
  }

  /// Some websites have custom search results with custom elements (e.g. preview images). Only return simple word based search suggestions
  // TODO: Create more advanced search suggestions (e.g. video, authors) or with filters
  Future<List<String>> getSearchSuggestions(String searchString);

  void displayError(String error) async {
    throw Exception(error);
  }
}
