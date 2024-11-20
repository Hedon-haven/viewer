import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:html/dom.dart";
import "package:http/http.dart" as http;
import "package:yaml/yaml.dart";

import "/backend/universal_formats.dart";
import "/main.dart";

class PluginInterface {
  /// This is overriden to true in official plugins
  final bool isOfficialPlugin = false;

  /// The path to the root of the plugin
  // ignore: prefer_final_fields
  String _pluginPath = "";

  /// codeName must be a unique identifier for the plugin, to avoid conflicts,
  /// especially if the plugin overrides an official plugin. Cannot be empty
  /// Cannot contain spaces, special chars or non-latin characters, as its used
  /// as the directory name for the plugin.
  String codeName = "";

  /// prettyName must be the official, correctly cased name of the provider. Cannot be empty
  String prettyName = "";

  /// Plugin version
  double version = 0.0;

  /// UpdateUri is optional. If provided, it will be used to check for updates.
  Uri? updateUrl;

  /// The path of the plugin binary to be executed.
  String _binaryPath = "";

  /// The path to the cache dir, which is usually a symlink to the Platforms cache dir for the app
  String _cachePath = "";

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

  /// Initial search page number
  int initialCommentsPage = 0;

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
    _binaryPath = "$_pluginPath/bin/binaryLink";
    _cachePath = "$_pluginPath/cache";
    if (!checkAndLoadFromConfig("$_pluginPath/plugin.yaml")) {
      throw Exception(
          "Failed to load from config file: $_pluginPath/plugin.yaml");
    }
  }

  bool checkAndLoadFromConfig(String configPath) {
    try {
      var config = loadYaml(File(configPath).readAsStringSync());
      codeName = config["codeName"];
      prettyName = config["prettyName"];
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
      logger.e("Error loading configuration: $e");
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
          logger.e("Received no response from process");
          throw Exception("No response from $codeName plugin");
        }
        // if the decoding fails at char 1 (i.e. its not a json at all, rather than a broken json)
        // treat it as an info log from the plugin
        else if (e is FormatException &&
            e.toString().startsWith(
                "FormatException: Unexpected character (at character 1)")) {
          if (responseString != null) {
            logger.i("$codeName: $responseString");
          }
        } else {
          rethrow;
        }
      }
    });

    pluginProcess.exitCode.then((value) {
      if (value != 0) {
        logger.e("Plugin process didn't exit cleanly, exit code: $value");
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
        previewVideo: result["videoPreview"] != null
            ? Uri.parse(result["videoPreview"])
            : null,
        duration: result["duration"] != null
            ? Duration(seconds: int.parse(result["duration"]))
            : null,
        viewsTotal: result["viewsTotal"],
        ratingsPositivePercent: result["ratingsPositivePercent"],
        maxQuality: result["maxQuality"],
        virtualReality: result["virtualReality"],
        author: result["author"],
        verifiedAuthor: result["verifiedAuthor"],
      );
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
        uploadDate: pluginResponse["uploadDate"] != null
            ? DateTime.parse(pluginResponse["uploadDate"]!)
            : null,
        ratingsPositiveTotal: pluginResponse["ratingsPositiveTotal"],
        ratingsNegativeTotal: pluginResponse["ratingsNegativeTotal"],
        ratingsTotal: pluginResponse["ratingsTotal"],
        virtualReality: pluginResponse["virtualReality"],
        chapters: pluginResponse["chapters"] != null
            ? jsonDecode(pluginResponse["chapters"]!).map((key, value) =>
                MapEntry(Duration(seconds: int.parse(key)), value))
            : null);
    return resultAsUniversalVM;
  }

  /// Get all progressThumbnails for a video and return them as a List
  Future<List<Uint8List>> getProgressThumbnails(
      String videoID, Document rawHtml) {
    throw UnimplementedError();
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

  /// Get comments for a video, per page
  Future<List<UniversalComment>> getComments(
      String videoID, Document rawHtml, int page) {
    throw UnimplementedError();
  }

  /// Some plugins might need to be prepared before they can be used (e.g. fetch cookies)
  Future<bool> initPlugin() async {
    try {
      await _runPlugin("getSearchResults", {});
    } catch (e) {
      return false;
    }
    return true;
  }

  /// Test full plugin functionality and return false if it fails
  bool runFunctionalityTest() {
    Map<String, dynamic> testResults = {"success": false};
    try {
      _runPlugin("runInitTest", {}).then((value) => testResults = value);
    } catch (e) {
      logger.i("Init test failed with: $e");
      return false;
    }
    return testResults["success"];
  }
}
