import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:flutter_hls_parser/flutter_hls_parser.dart";
import "package:hedon_viewer/backend/universal_formats.dart";
import "package:http/http.dart" as http;
import "package:yaml/yaml.dart";

class PluginInterface {
  /// The path to the root of the plugin
  String _pluginPath = "";

  /// name must be the official, correctly cased name of the provider. Must not contain commas (,). Cannot be empty.
  String name = "";

  /// Plugin version
  double version = 0.0;

  /// UpdateUri is optional. If provided, it will be used to check for updates.
  Uri? updateUrl;

  /// The path of the plugin binary to be executed.
  String _binaryPath = "";

  /// Icon must point to a small icon of the website, preferably the favicon
  Uri iconUrl = Uri.parse("");

  /// The base website url of the plugin provider, as a string. Example: https://example.com
  String providerUrl = "";

  /// Initial homepage number
  // Some sites start at 0, some at 1
  // 0 is usually the same as the homepage from pluginURL
  int initialHomePage = 0;

  /// Initial search page number
  int initialSearchPage = 0;

  /// Has a homepage
  bool providesHomepage = false;

  /// Provides search results
  bool providesResults = false;

  /// Provides search suggestions
  bool providesSearchSuggestions = false;

  /// Can return a video via a unique id
  bool providesVideo = false;

  /// Allows/Provides downloads
  bool providesDownloads = false;

  PluginInterface(this._pluginPath) {
    _binaryPath = "$_pluginPath/binary";
    if (!checkAndLoadFromConfig("$_pluginPath/plugin.yaml")) {
      throw Exception(
          "Failed to load from config file: $_pluginPath/plugin.yaml");
    }
  }

  bool checkAndLoadFromConfig(String configPath) {
    try {
      var config = loadYaml(File(configPath).readAsStringSync());
      name = config["name"];
      version = config["version"];
      updateUrl = Uri.parse(config["updateUrl"]);
      iconUrl = Uri.parse(config["iconUrl"]);
      providerUrl = config["providerUrl"];
      initialHomePage = config["initialHomePage"];
      initialSearchPage = config["initialSearchPage"];
      providesHomepage = config["providesHomepage"];
      providesResults = config["providesResults"];
      providesSearchSuggestions = config["providesSearchSuggestions"];
      providesVideo = config["providesVideo"];
      providesDownloads = config["providesDownloads"];
    } catch (e) {
      print("Error loading configuration: $e");
      return false;
    }
    return true;
  }

  void displayError(String error) async {
    throw Exception(error);
  }

  Future<Map<String, dynamic>> _runPlugin(
      String command, Map<String, dynamic> arguments) async {
    Process pluginProcess = await Process.start(_binaryPath, [command]);
    pluginProcess.stdin.write(jsonEncode(arguments));
    await pluginProcess.stdin.flush();
    pluginProcess.stdin.close();

    Map<String, dynamic> responseMap = {};
    pluginProcess.stdout.listen((List<int> list) {
      String? responseString;
      try {
        // Decode response into a String and then into a map
        responseString = utf8.decode(list).trim();
        responseMap = json.decode(responseString);
      } catch (e) {
        if (e is StateError && e.message == "No element") {
          print("Received no response from process");
        }
        // if the decoding fails at char 1 (i.e. its not a json at all, rather than a broken json)
        // treat it as a debug log from the plugin
        else if (e is FormatException &&
            e.toString().startsWith(
                "FormatException: Unexpected character (at character 1)")) {
          if (responseString != null) {
            print("$name: $responseString");
          }
        } else {
          rethrow;
        }
      }
    });

    pluginProcess.exitCode.then((value) {
      if (value != 0) {
        print("Plugin process didn't exit cleanly, exit code: $value");
      }
    });

    // wait for plugin to finish
    await pluginProcess.exitCode;
    // TODO: Return exit code
    return responseMap;
  }

  /// Return the homepage
  Future<List<UniversalSearchResult>> getHomePage(int page) async {
    Map<String, dynamic> arguments = {"page": page};
    Map<String, dynamic> pluginResponse =
        await _runPlugin("getHomePage", arguments);
    return _parseVideoPage(pluginResponse);
  }

  /// Return list of search results
  Future<List<UniversalSearchResult>> getSearchResults(
      UniversalSearchRequest sr, int page) async {
    Map<String, dynamic> arguments = {
      "page": page,
      "searchRequest": json.encode(sr.convertToMap())
    };
    Map<String, dynamic> pluginResponse =
        await _runPlugin("getSearchResults", arguments);

    return _parseVideoPage(pluginResponse);
  }

  List<UniversalSearchResult> _parseVideoPage(
      Map<String, dynamic> pluginResponse) {
    List<UniversalSearchResult> resultsMap = [];
    // iterate over results and convert them to UniversalSearchResults
    for (String resultString in pluginResponse.values) {
      Map<String, dynamic> result = jsonDecode(resultString);
      UniversalSearchResult newResult = UniversalSearchResult(
        videoID: result["videoID"]!,
        title: result["title"]!,
        plugin: this,
        thumbnail: result["thumbnail"],
        // videoPreview must be converted
        // duration must be converted
        viewsTotal: result["viewsTotal"],
        ratingsPositivePercent: result["ratingsPositivePercent"],
        maxQuality: result["maxQuality"],
        virtualReality: result["virtualReality"],
        author: result["author"],
        verifiedAuthor: result["verifiedAuthor"],
      );
      // Uris and durations are objects and cannot be encoded into json -> must be converted from strings
      if (result["videoPreview"] != null) {
        newResult.videoPreview = Uri.parse(result["videoPreview"]!);
      }
      if (result["duration"] != null) {
        newResult.duration = Duration(seconds: int.parse(result["duration"]!));
      }
      resultsMap.add(newResult);
    }
    return resultsMap;
  }

  /// Request video metadata and convert it to UniversalFormat
  Future<UniversalVideoMetadata> getVideoMetadata(String videoID) async {
    Map<String, String> arguments = {"videoId": videoID};
    Map<String, dynamic> pluginResponse =
        await _runPlugin("getVideoMetadata", arguments);

    UniversalVideoMetadata resultAsUniversalVM = UniversalVideoMetadata(
      videoID: videoID,
      m3u8Uris: jsonDecode(pluginResponse["m3u8Uris"]!)
          .map((key, value) => MapEntry(int.parse(key), Uri.parse(value))),
      title: pluginResponse["title"]!,
      plugin: this,
      author: pluginResponse["author"],
      authorID: pluginResponse["authorID"],
      actors: pluginResponse["actors"],
      description: pluginResponse["description"],
      viewsTotal: pluginResponse["viewsTotal"],
      tags: pluginResponse["tags"],
      categories: pluginResponse["categories"],
      // uploadDate must be converted
      ratingsPositiveTotal: pluginResponse["ratingsPositiveTotal"],
      ratingsNegativeTotal: pluginResponse["ratingsNegativeTotal"],
      ratingsTotal: pluginResponse["ratingsTotal"],
      virtualReality: pluginResponse["virtualReality"],
      // chapters must be converted
    );

    // uploadDate and chapters map are objects and cannot be encoded into json -> must be converted from strings
    if (pluginResponse["uploadDate"] != null) {
      resultAsUniversalVM.uploadDate =
          DateTime.parse(pluginResponse["uploadDate"]!);
      if (pluginResponse["chapters"] != null) {
        resultAsUniversalVM.chapters = jsonDecode(pluginResponse["chapters"]!)
            .map((key, value) =>
                MapEntry(Duration(seconds: int.parse(key)), value));
      }
    }
    return resultAsUniversalVM;
  }

  /// Some websites have custom search results with custom elements (e.g. preview images). Only return simple word based search suggestions
  // TODO: Create more advanced search suggestions (e.g. video, authors) or with filters
  Future<List<String>> getSearchSuggestions(String searchString) async {
    Map<String, String> arguments = {"searchString": searchString};
    Map<String, dynamic> pluginResponse =
        await _runPlugin("getVideoMetadata", arguments);
    return pluginResponse["searchSuggestions"];
  }

  /// This function returns the request thumbnail as a blob
  //TODO: Add option in plugin.yaml to override this function if needed
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
}
