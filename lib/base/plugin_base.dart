import 'dart:async';
import 'dart:convert';

import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

abstract class PluginBase {
  // pluginName must be the official, correctly cased name of the provider
  String pluginName = "";

  /// Return list of search results by string
  Future<List<UniversalSearchResult>> search(UniversalSearchRequest request);

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
      handleRequestError(response);
      return {}; // return an empty Map for now
    }
  }

  // Use this function instead of reimplementing it in plugins, as this function is able to handle errors properly
  /// download and parse html
  Future<Document> requestHtml(String uri) async {
    var response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      return parse(response.body);
    } else {
      handleRequestError(response);
      return parse("");
    }
  }

  void handleRequestError(http.Response errorResponse) async {
    // TODO: Show error popup in UI
    print("Err: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}");
  }
}
