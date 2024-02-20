import 'dart:async';
import 'dart:convert';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

abstract class PluginBase {
  // pluginName must be the official, correctly cased name of the provider
  String pluginName = "";

  /// Return list of search results by string
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page);

  /// Request video metadata and convert it to UniversalFormat
  Future<UniversalVideoMetadata> getVideoMetadataAsUniversalFormat(
      String videoId);

  // Use this function instead of reimplementing it in plugins, as this function is able to handle errors properly
  /// download and parse json
  Future<Map> requestJson(Uri uri) async {
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      displayError(
          "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
      return {};
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
    var response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      return parse(response.body);
    } else {
      displayError(
          "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
      return parse("");
    }
  }

  void displayError(String error) async {
    // TODO: Show error popup in UI
    ToastMessageShower.showToast(error);
    throw Exception(error);
  }
}
