import 'dart:async';
import 'dart:convert';

import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

abstract class PluginBase {
  // pluginName must be the official, correctly cased name of the provider
  String pluginName = "";
  String apiUrl = "";
  String searchEndpoint = "";
  String searchEndpointExtraArgs = "";
  String videoEndpoint = "";
  String videoEndpointExtraArgs = "";

  Future<UniversalSearchResult> searchWithString(String searchString) async {
    var combinedUri = Uri.parse(
        apiUrl + searchEndpoint + searchString + searchEndpointExtraArgs);
    var responseJson = await requestJson(combinedUri);
    if (responseJson != {}) {
      return convertSearchToUniversalFormat(responseJson);
    } else {
      return UniversalSearchResult.error();
    }
  }

  /// Convert the received json to universal search map format
  Future<UniversalSearchResult> convertSearchToUniversalFormat(Map searchJson);

  /// Request video metadata and convert it to UniversalFormat
  Future<UniversalVideoMetadata> getVideoMetadataAsUniversalFormat(
      String videoId);

  Future<Map> requestJson(Uri uri) async {
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      handleRequestError(response);
      return {}; // return an empty Map for now
    }
  }

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
