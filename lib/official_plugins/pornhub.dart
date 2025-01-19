import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';

import '/utils/global_vars.dart';
import '/utils/official_plugin.dart';
import '/utils/plugin_interface.dart';
import '/utils/universal_formats.dart';

class PornhubPlugin extends OfficialPlugin implements PluginInterface {
  @override
  final bool isOfficialPlugin = true;
  @override
  String codeName = "pornhub-official";
  @override
  String prettyName = "Pornhub.com";
  @override
  Uri iconUrl = Uri.parse("https://www.pornhub.com/favicon.ico");
  @override
  String providerUrl = "https://www.pornhub.com";
  @override
  int initialHomePage = 0;
  @override
  int initialSearchPage = 1;
  @override
  int initialCommentsPage = 1;
  @override
  int initialVideoSuggestionsPage = 1;
  @override
  bool providesHomepage = true;
  @override
  bool providesSearchSuggestions = true;
  @override
  bool providesResults = true;
  @override
  bool providesVideo = true;
  @override
  bool providesDownloads = true;

  // The following fields are inherited from PluginInterface, but not needed due to this class not actually being an interface
  @override
  Uri? updateUrl;
  @override
  double version = 1.0;

  // Set OfficialPlugin specific vars
  @override
  Map<String, dynamic> testingMap = {
    "ignoreScrapedErrors": {
      "homepage": ["thumbnailBinary", "maxQuality", "lastWatched", "addedOn"],
      "searchResults": [
        "thumbnailBinary",
        "maxQuality",
        "lastWatched",
        "addedOn"
      ],
      "videoMetadata": ["chapters", "description"],
      "videoSuggestions": [
        "thumbnailBinary",
        "lastWatched",
        "addedOn",
        "maxQuality"
      ],
      "comments": [
        "authorID",
        "countryID",
        "orientation",
        "ratingsPositiveTotal",
        "ratingsNegativeTotal",
        "replyComments"
      ]
    },
    "testingVideos": [
      // This is the most watched video on pornhub
      {"videoID": "2006034279", "progressThumbnailsAmount": 300},
      // This is a more recent video
      {"videoID": "675b20362274f", "progressThumbnailsAmount": 600}
    ]
  };

  // Private hardcoded vars
  final String _videoEndpoint =
      "https://www.pornhub.com/view_video.php?viewkey=";
  final String _searchEndpoint = "https://www.pornhub.com/video/search?search=";

  // Store session cookies created by initPlugin
  final Map<String, String> _sessionCookies = {"ss": "", "token": ""};
  final Map<String, String> _sortingTypeMap = {
    "Relevance": "",
    "Upload date": "&o=mr",
    "Views": "&o=mv",
    "Rating": "&o=tr",
    "Duration": "&o=lg"
  };
  final Map<String, String> _dateRangeMap = {
    "All time": "",
    "Last year": "&t=y",
    "Last month": "&t=m",
    "Last week": "&t=w",
    "Last day/Last 3 days/Latest": "&t=t"
  };
  final Map<int, String> _minDurationMap = {
    0: "",
    5: "", // pornhub doesnt support 5 min -> use 0
    10: "&min_duration=10",
    20: "&min_duration=20",
    30: "&min_duration=30",
    60: ""
  };
  final Map<int, String> _maxDurationMap = {
    0: "",
    300: "", // pornhub doesnt support 5 min -> use 0
    600: "&max_duration=10",
    1200: "&max_duration=20",
    1800: "&max_duration=30",
    3600: ""
  };

  Future<List<UniversalVideoPreview>> _parseVideoList(
      List<Element> resultsList) async {
    // convert the divs into UniversalSearchResults
    List<UniversalVideoPreview> results = [];
    for (Element resultElement in resultsList) {
      // Try to parse as all video previews and ignore errors
      // If more than 50% of elements fail, an exception will be thrown
      try {
        String? iD = resultElement.attributes['data-video-vkey'];

        Element resultDiv = resultElement.querySelector("div")!;

        // first div is phimage
        Element? imageDiv = resultDiv.querySelector("a");
        String? thumbnail = imageDiv?.querySelector("img")?.attributes["src"];
        String? videoPreview = imageDiv?.attributes["data-webm"];

        // convert time string into int list
        // pornhub automatically converts hours into minutes -> no need to check
        List<int>? durationList = resultDiv
            .querySelector('span[class*="time"]')
            ?.text
            .trim()
            .split(":")
            .map((e) => int.parse(e))
            .toList();
        Duration? duration;
        if (durationList != null) {
          duration = Duration(seconds: durationList[0] * 60 + durationList[1]);
        }

        // check if video is vr
        bool virtualReality = false;
        if (resultDiv
                .querySelector('span[class="hd-thumbnail vr-thumbnail"]') !=
            null) {
          virtualReality = true;
        }

        // the title field can have different names
        String? title = resultDiv
            .querySelector('div[class="title"]')
            ?.querySelector("a")
            ?.text
            .trim();

        // the author field can be a link or a span
        String? author = resultDiv
            .querySelector('a[class*="uploaderLink"], '
                'span[class*="uploaderLink"]')
            ?.text
            .trim();

        // determine video views
        int? views;
        String? viewsString = resultDiv
            // the div is called videoViews on the first homepagle and just views on all others
            .querySelector('div[class="videoViews"], div[class="views"]')
            ?.text
            .replaceAll("Views", "")
            .trim();

        // just added means 0, means skip the whole part coz views is already 0
        if (viewsString == "just added") {
          views = 0;
        } else if (viewsString != null) {
          views = 0;
          if (viewsString.endsWith("K")) {
            if (viewsString.contains(".")) {
              views = int.parse(viewsString.split(".")[1][0]) * 100;
              // this is so that the normal step still works
              // ignore: prefer_interpolation_to_compose_strings
              viewsString = viewsString.split(".")[0] + " ";
            }
            views +=
                int.parse(viewsString.substring(0, viewsString.length - 1)) *
                    1000;
          } else if (viewsString.endsWith("M")) {
            if (viewsString.contains(".")) {
              views = int.parse(viewsString.split(".")[1][0]) * 100000;
              // this is so that the normal step still works
              // ignore: prefer_interpolation_to_compose_strings
              viewsString = viewsString.split(".")[0] + " ";
            }
            views +=
                int.parse(viewsString.substring(0, viewsString.length - 1)) *
                    1000000;
          } else {
            views = int.tryParse(viewsString);
          }
        }

        String? ratingsString = resultDiv
            .querySelector('div[class="rating neutral"]')
            ?.text
            .replaceAll("%", "")
            .trim();
        int? ratings;
        if (ratingsString != null) {
          ratings = int.tryParse(ratingsString);
        }

        // TODO: determine video resolution
        // pornhub only offers up to 1080p

        UniversalVideoPreview uniResult = UniversalVideoPreview(
          videoID: iD!,
          title: title!,
          plugin: this,
          thumbnail: thumbnail,
          previewVideo:
              videoPreview != null ? Uri.tryParse(videoPreview) : null,
          duration: duration,
          viewsTotal: views,
          ratingsPositivePercent: ratings,
          maxQuality: null,
          virtualReality: virtualReality,
          author: author,
          // All authors on pornhub are verified
          verifiedAuthor: true,
        );

        // getHomepage, getSearchResults and getVideoSuggestions all use the same _parseVideoList
        // -> their ignore lists are the same
        uniResult.verifyScrapedData(
            codeName, testingMap["ignoreScrapedErrors"]["homepage"]);

        results.add(uniResult);
      } catch (e, stacktrace) {
        logger.e("Error parsing element. Continuing anyways: $e\n$stacktrace");
      }
    }

    if (results.length != resultsList.length) {
      logger.w("${resultsList.length - results.length} video previews failed "
          "to parse.");
      if (results.length < resultsList.length * 0.5) {
        throw Exception("More than 50% of the video previews failed to parse.");
      }
    }

    return results;
  }

  /// Pornhub doesn't provide timestamps, only approximate human-readable strings. Convert them to DateTime objects to be more universal
  DateTime? _convertStringToDateTime(String? dateAsString) {
    DateTime? converted;
    if (dateAsString == null) {
      return null;
    }
    try {
      if (dateAsString.endsWith("seconds ago") ||
          dateAsString.endsWith("second ago")) {
        converted = DateTime.now()
            .subtract(Duration(seconds: int.parse(dateAsString[0])));
      } else if (dateAsString.endsWith("minutes ago") ||
          dateAsString.endsWith("minute ago")) {
        converted = DateTime.now()
            .subtract(Duration(minutes: int.parse(dateAsString[0])));
      } else if (dateAsString.endsWith("hours ago") ||
          dateAsString.endsWith("hour ago")) {
        converted = DateTime.now()
            .subtract(Duration(hours: int.parse(dateAsString[0])));
      } else if (dateAsString == "Yesterday") {
        converted = DateTime.now().subtract(const Duration(days: 1));
      } else if (dateAsString.endsWith("days ago")) {
        converted =
            DateTime.now().subtract(Duration(days: int.parse(dateAsString[0])));
      } else if (dateAsString.endsWith("weeks ago") ||
          dateAsString.endsWith("week ago")) {
        converted = DateTime.now()
            .subtract(Duration(days: int.parse(dateAsString[0]) * 7));
      } else if (dateAsString.endsWith("months ago") ||
          dateAsString.endsWith("month ago")) {
        converted = DateTime.now()
            .subtract(Duration(days: int.parse(dateAsString[0]) * 30));
      } else if (dateAsString.endsWith("years ago") ||
          dateAsString.endsWith("year ago")) {
        converted = DateTime.now()
            .subtract(Duration(days: int.parse(dateAsString[0]) * 365));
      } else {
        logger.w("Could not convert date string to DateTime: $dateAsString");
      }
    } catch (e, stacktrace) {
      logger.w("Error converting date string to DateTime: $e\n$stacktrace");
      return null;
    }
    return converted;
  }

  @override
  Future<bool> initPlugin() async {
    logger.i("Initializing $codeName plugin");
    // To be able to make search suggestion requests later, both a session cookie and a token are needed
    // Get the sessions cookie (called ss) from the response headers
    String? setCookies;
    http.Response response = await http.get(Uri.parse(providerUrl));
    if (response.statusCode != 200) {
      return Future.value(false);
    }
    setCookies = response.headers['set-cookie'];
    Document rawHtml = parse(response.body);

    if (setCookies != null) {
      List<String> cookiesList = setCookies.split(',');
      for (var i = 0; i < cookiesList.length; i++) {
        if (cookiesList[i].contains("ss=")) {
          _sessionCookies["ss"] =
              cookiesList[i].substring(3, cookiesList[i].indexOf(";"));
          logger.i("Session cookie: ${_sessionCookies["ss"]}");
        }
      }
    } else {
      logger.e("No set-cookies received; couldn't extract session cookie");
      return Future.value(false);
    }

    // From the same request get the token inside the html
    String? rawHtmlHead = rawHtml.head?.text;
    if (rawHtmlHead != null) {
      String tokenHtml = rawHtmlHead.substring(rawHtmlHead.indexOf("token"));
      _sessionCookies["token"] = tokenHtml.substring(
          tokenHtml.indexOf('= "') + 3, tokenHtml.indexOf('",'));
      logger.i("Token: ${_sessionCookies["token"]}");
    } else {
      logger.e("No token received or found; couldn't extract token");
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  bool runFunctionalityTest() {
    // There is no need to run functionality tests on official plugins
    // as they are not imported at any time in the app
    // Also, these plugins get checked for functionality via daily CIs
    return true;
  }

  // downloadThumbnail is implemented at the PluginBase level

  @override
  Future<List<String>> getSearchSuggestions(String searchString) async {
    logger.d("Getting search suggestions for $searchString");
    final Uri requestUri = Uri.parse(
        "https://www.pornhub.com/video/search_autocomplete?&token=${_sessionCookies["token"]}&q=$searchString");
    logger
        .d("Request URI: $requestUri with ss cookie: ${_sessionCookies["ss"]}");
    final response = await http
        .get(requestUri, headers: {"Cookie": "ss=${_sessionCookies["ss"]}"});
    Map<String, dynamic> data = jsonDecode(response.body);
    // The search results are just returned as key value pairs of numbers
    // e.g. {"0": "suggestion1", "1": "suggestion2", "2": "suggestion3"}
    // combine them into a simple list
    List<String> suggestions = [];
    data.forEach((key, value) {
      if (key != "isDdBannedWord" && key != "popularSearches") {
        suggestions.add(value);
      }
    });
    return suggestions;
  }

  @override
  Future<List<UniversalVideoPreview>> getHomePage(int page) async {
    List<Element>? resultsList;
    // pornhub has a homepage and a separate page 1 video homepage
    // -> load main homepage first, then load first video homepage
    if (page == 0) {
      // page=0 returns a different page than requesting the base website
      logger.d("Requesting $providerUrl");
      var response = await http.get(Uri.parse(providerUrl),
          // Mobile video image previews are higher quality
          headers: {"Cookie": "platform=mobile"});
      if (response.statusCode != 200) {
        logger.e(
            "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
        throw Exception(
            "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
      }
      // Filter out ads and non-video results
      resultsList = parse(response.body)
          // the base page has a different id for the video list
          .querySelector('#singleFeedSection')
          ?.querySelectorAll('li[data-video-vkey]')
          .toList();
    } else {
      logger.d("Requesting $providerUrl/video?page=$page");
      var response = await http.get(Uri.parse("$providerUrl/video?page=$page"),
          // Mobile video image previews are higher quality
          headers: {"Cookie": "platform=mobile"});
      if (response.statusCode != 200) {
        logger.e(
            "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
        throw Exception(
            "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
      }
      // Filter out ads and non-video results
      resultsList = parse(response.body)
          .querySelector('ul[class^="videoList"]')
          ?.querySelectorAll('li[data-video-vkey]')
          .toList();
    }
    return _parseVideoList(resultsList!);
  }

  @override
  Future<List<UniversalVideoPreview>> getSearchResults(
      UniversalSearchRequest request, int page) async {
    // Pornhub doesn't allow empty search queries
    if (request.searchString.isEmpty) {
      return [];
    }
    String encodedSearchString = Uri.encodeComponent(request.searchString);
    // @formatter:off
    // Pornhub does not accept redundant search parameters.
    // For example passing &min_duration=0 will result in a 404, even though technically 0 is the default duration in the website's ui
    // ignore: prefer_interpolation_to_compose_strings
    String urlString = _searchEndpoint + encodedSearchString
        + "&page=$page"
        + _sortingTypeMap[request.sortingType]!
        // only top rated and most views support sorting by date
        + (request.sortingType == "Rating" || request.sortingType == "Views" ? _dateRangeMap[request.dateRange]!: "")
        // pornhub considers 720p to be hd. No further narrowing is possible in the url
        + (request.minQuality >= 720 ? "&hd=1" : "")
        + _minDurationMap[request.minDuration]!
        + _maxDurationMap[request.maxDuration]!
    ;
    // @formatter:on

    logger.d("Requesting $urlString");
    var response = await http.get(Uri.parse(urlString),
        // Mobile video image previews are higher quality
        headers: {"Cookie": "platform=mobile"});
    if (response.statusCode != 200) {
      logger.e(
          "Error downloading $urlString: ${response.statusCode} - ${response.reasonPhrase}");
      throw Exception(
          "Error downloading $urlString: ${response.statusCode} - ${response.reasonPhrase}");
    }
    Document resultHtml = parse(response.body);
    if (resultHtml.outerHtml == "<html><head></head><body></body></html>") {
      throw Exception("Received empty html");
    }
    // Filter out ads and non-video results
    List<Element>? resultsList = resultHtml
        .querySelector('ul[id="videoListSearchResults"]')
        ?.querySelectorAll('li[class^="videoSearchList_"]')
        .toList();
    return _parseVideoList(resultsList!);
  }

  @override
  Future<List<UniversalVideoPreview>> getVideoSuggestions(
      String videoID, Document rawHtml, int page) async {
    // Pornhub doesn't allow loading more suggestions
    if (page > 1) {
      return Future.value([]);
    }

    // Filter out ads and non-video results
    return await _parseVideoList(rawHtml
        .querySelector("#relatedVideos")!
        .querySelectorAll('li[data-video-vkey]')
        .toList());
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(String videoId, UniversalVideoPreview uvp) async {
    Uri videoMetadata = Uri.parse(_videoEndpoint + videoId);
    logger.d("Requesting $videoMetadata");
    var response = await http.get(
      videoMetadata,
      // This header allows getting more data (such as recommended videos which are later used by getRecommendedVideos)
      headers: {"Cookie": "accessAgeDisclaimerPH=1;platform=mobile"},
    );
    if (response.statusCode != 200) {
      logger.e(
          "Error downloading html: ${response.statusCode} - ${response.reasonPhrase}");
      throw Exception(
          "Error downloading html: ${response.statusCode} -l ${response.reasonPhrase}");
    }

    Document rawHtml = parse(response.body);

    // Get the video javascript and convert the main json into a map
    String jscript =
        rawHtml.querySelector("#mobileContainer > script:nth-child(1)")!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

    // ratings
    int? ratingsPositive;
    String? ratingsPositiveString = rawHtml
        .querySelector('button[id="thumbs-up"]')
        ?.querySelector("span")
        ?.text
        .trim();
    if (ratingsPositiveString != null) {
      if (ratingsPositiveString.endsWith("K")) {
        ratingsPositive = int.parse(ratingsPositiveString.substring(
                0, ratingsPositiveString.length - 1)) *
            1000;
      } else {
        ratingsPositive = int.tryParse(ratingsPositiveString);
      }
    }

    int? ratingsNegative;
    String? ratingsNegativeString = rawHtml
        .querySelector('button[id="thumbs-down"]')
        ?.querySelector("span")
        ?.text
        .trim();
    if (ratingsNegativeString != null) {
      if (ratingsNegativeString.endsWith("K")) {
        ratingsNegative = int.parse(ratingsNegativeString.substring(
                0, ratingsNegativeString.length - 1)) *
            1000;
      } else {
        ratingsNegative = int.tryParse(ratingsNegativeString);
      }
    }

    int? ratingsTotal;
    if (ratingsPositive != null && ratingsNegative != null) {
      ratingsTotal = ratingsPositive + ratingsNegative;
    }

    // For some reason on mobile the full exact view amount is always shown
    int? viewsTotal;
    String? viewsString = rawHtml
        .querySelector('li[class="views"]')
        ?.querySelector("span")
        ?.text
        .replaceAll(",", "")
        .trim();

    if (viewsString != null) {
      viewsTotal = int.tryParse(viewsString);
    }

    // author
    Element? authorRaw = rawHtml
        .querySelector('span[class="usernameBadgesWrapper"]')
        ?.querySelector("a");

    String? authorString = authorRaw?.text;
    String? authorId = authorRaw?.attributes["href"];

    // actors
    List<Element>? actorsList = rawHtml
        .querySelector('div[class*="pornstarsWrapper"]')
        ?.querySelectorAll("a");

    List<String>? actors = [];
    if (actorsList != null) {
      for (Element element in actorsList) {
        actors.add(element.text);
      }
    }
    // Only set actors to null (i.e. failed), if the element wasn't scraped properly
    // Some videos don't have actors at all -> don't set to null in such cases
    if (actors.isEmpty &&
        rawHtml.querySelector('div[class*="pornstarsWrapper"]')?.text.trim() !=
            "Pornstars") {
      actors = null;
    }

    // categories
    List<Element>? categoriesList = rawHtml
        .querySelector('div[class*="categoriesWrapper"]')
        ?.querySelectorAll("a");

    List<String>? categories = [];
    if (categoriesList != null) {
      for (Element element in categoriesList) {
        categories.add(element.text);
      }
    }
    // Only set categories to null (i.e. failed), if the element wasn't scraped properly
    // Some videos don't have categories at all -> don't set to null in such cases
    if (categories.isEmpty &&
        rawHtml.querySelector('div[class*="categoriesWrapper"]')?.text.trim() !=
            "Categories") {
      categories = null;
    }

    // tags
    List<Element>? tagsList = rawHtml
        .querySelector('div[class*="tagsWrapper"]')
        ?.querySelectorAll("a");

    List<String>? tags = [];
    if (tagsList != null) {
      for (Element element in tagsList) {
        tags.add(element.text);
      }
    }
    // Only set tags to null (i.e. failed), if the element wasn't scraped properly
    // Some videos don't have tags at all -> don't set to null in such cases
    if (tags.isEmpty &&
        rawHtml.querySelector('div[class*="tagsWrapper"]')?.text.trim() !=
            "Tags") {
      categories = null;
    }

    // Pornhub doesn't provide exact timestamps -> convert it
    DateTime? uploadDate = _convertStringToDateTime(
        rawHtml.querySelector('li[class="added"]')?.text.trim());

    Map<int, Uri> m3u8Map = {};
    for (Map<String, dynamic> video in jscriptMap["mediaDefinitions"]) {
      if (video["format"] == "hls") {
        // the last quality is a List of all qualities -> ignore it
        var quality = video["quality"];
        if (quality.runtimeType == String) {
          m3u8Map[int.parse(quality)] = Uri.parse(video["videoUrl"]);
        }
      }
    }

    UniversalVideoMetadata metadata = UniversalVideoMetadata(
        videoID: videoId,
        m3u8Uris: m3u8Map,
        title: jscriptMap["video_title"]!,
        plugin: this,
        universalVideoPreview: uvp,
        author: authorString,
        authorID: authorId,
        actors: actors,
        description: rawHtml
            .querySelector(
                'div[class="categoryRow targetContainer displayNone clearfix"]')
            ?.querySelector("span")
            ?.text
            .trim(),
        viewsTotal: viewsTotal,
        tags: tags,
        categories: categories,
        uploadDate: uploadDate,
        ratingsPositiveTotal: ratingsPositive,
        ratingsNegativeTotal: ratingsNegative,
        ratingsTotal: ratingsTotal,
        virtualReality: jscriptMap["isVR"] == 1,
        chapters: null,
        rawHtml: rawHtml);

    // print warnings if some data is missing
    // The description element is completely missing from the page if no
    // description was provided -> allow scraping failure
    metadata.verifyScrapedData(
        codeName, testingMap["ignoreScrapedErrors"]["videoMetadata"]);

    return metadata;
  }

  @override
  Future<void> isolateGetProgressThumbnails(SendPort sendPort) async {
    // Receive data from the main isolate
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final message = await receivePort.first as List;
    final rootToken = message[0] as RootIsolateToken;
    final resultsPort = message[1] as SendPort;
    final logPort = message[2] as SendPort;
    //final videoID = message[3] as String;
    final rawHtml = message[4] as Document;

    // Not quite sure what this is needed for, but fails otherwise
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    try {
      // Get the video javascript
      String jscript =
          rawHtml.querySelector("#mobileContainer > script:nth-child(1)")!.text;
      Map<String, dynamic> jscriptMap = jsonDecode(
          jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));

      // Extract the progressImage url from jscript
      String imageUrl = jscriptMap["thumbs"]["urlPattern"];
      logPort.send(["debug", "Image url: $imageUrl"]);

      // Extract the sampling frequency
      int samplingFrequency = jscriptMap["thumbs"]["samplingFrequency"];
      logPort.send(["debug", "Sampling frequency: $imageUrl"]);

      String suffix = ".${imageUrl.split(".").last}";
      logPort.send(["debug", "Suffix: $suffix"]);
      int lastImageIndex = int.parse(imageUrl.split("{").last.split("}").first);
      logPort.send(["debug", "Last image index: $lastImageIndex"]);
      String baseUrl = imageUrl.split("{").first;
      logPort.send(["debug", "BaseURL: $baseUrl"]);

      logPort.send(["info", "Downloading and processing progress images"]);
      List<List<Uint8List>> allThumbnails =
          List.generate(lastImageIndex + 1, (_) => []);
      List<Future<void>> imageFutures = [];

      for (int i = 0; i <= lastImageIndex; i++) {
        // Create a future for downloading and processing
        imageFutures.add(Future(() async {
          logPort.send(["debug", "Preparing to download $baseUrl$i$suffix"]);
          Uint8List image =
              await downloadThumbnail(Uri.parse("$baseUrl$i$suffix"));
          final decodedImage = decodeImage(image)!;
          List<Uint8List> thumbnails = [];
          for (int h = 0; h <= 360; h += 90) {
            for (int w = 0; w <= 640; w += 160) {
              // every progress image is for samplingFrequency (usually 4 or 9) seconds -> store the same image samplingFrequency times
              // To avoid overfilling the ram, create a temporary variable and store it in the list multiple times
              // As Lists contain references to data and not the data itself, this should reduce ram usage
              Uint8List firstThumbnail = Uint8List(0);
              for (int j = 0; j < samplingFrequency; j++) {
                if (j == 0) {
                  // Only encode and add the first image once
                  firstThumbnail = encodeJpg(copyCrop(decodedImage,
                      x: w, y: h, width: 160, height: 90));
                  thumbnails.add(firstThumbnail); // Add the first encoded image
                } else {
                  // Reuse the reference to the first thumbnail
                  thumbnails.add(firstThumbnail);
                }
              }
            }
          }
          allThumbnails[i] = thumbnails;
          logPort.send(["debug", "Completed processing $baseUrl$i$suffix"]);
        }));
      }
      // Await all futures
      await Future.wait(imageFutures);

      // Combine all results into single, chronological list
      logPort.send(
          ["debug", "Combining all results into single, chronological list"]);
      List<Uint8List> completedProcessedImages =
          allThumbnails.expand((x) => x).toList();

      logPort.send(["info", "Completed processing all images"]);
      // return the completed processed images through the separate resultsPort
      logPort.send([
        "debug",
        "Sending ${completedProcessedImages.length} progress images to main process"
      ]);
      resultsPort.send(completedProcessedImages);
    } catch (e, stackTrace) {
      logPort.send(
          ["error", "Error in isolateGetProgressThumbnails: $e\n$stackTrace"]);
      resultsPort.send(null);
    }
  }

  @override
  Future<List<UniversalComment>> getComments(
      String videoID, Document rawHtml, int page) async {
    // Private functions
    UniversalComment parseComment(
        Element comment, String videoID, bool hidden) {
      Element tempComment = comment.children.first;
      UniversalComment parsedComment = UniversalComment(
          videoID: videoID,
          author: tempComment
              .querySelector('img[class="commentAvatarImg avatarTrigger"]')!
              .attributes["title"]!,
          commentBody: tempComment
              .querySelector("div[class=commentMessage]")!
              .children
              .first
              .text
              .trim(),
          hidden: hidden,
          plugin: this,
          // Sometimes the authorID is "unknown" (not a link) -> allow null
          authorID: tempComment
              .querySelector('a[class="userLink clearfix"]')
              ?.attributes["href"]
              ?.substring(7),
          commentID:
              comment.className.split(" ")[2].replaceAll("commentTag", ""),
          countryID: null,
          orientation: null,
          profilePicture: tempComment
              .querySelector('img[class="commentAvatarImg avatarTrigger"]')
              ?.attributes["src"],
          ratingsPositiveTotal: null,
          ratingsNegativeTotal: null,
          ratingsTotal: int.tryParse(
              tempComment.querySelector('span[class*="voteTotal"]')?.text ??
                  ""),
          commentDate: _convertStringToDateTime(
              tempComment.querySelector('div[class="date"]')?.text.trim()),
          replyComments: []);

      parsedComment.verifyScrapedData(
          codeName, testingMap["ignoreScrapedErrors"]["comments"]);

      return parsedComment;
    }

    /// Recursive function
    // TODO: Parallelize, but keep in mind that reply comments need to be able to be added to the prev top-level comment
    Future<List<UniversalComment>> parseCommentList(
        Element parent, String videoID, bool hidden) async {
      List<UniversalComment> parsedComments = [];
      for (Element child in parent.children) {
        // Try to parse as all elements and ignore errors
        // If more than 50% of elements fail, an exception will be thrown
        try {
          // normal / top-level comment
          if (child.className.startsWith("commentBlock")) {
            parsedComments.add(parseComment(child, videoID, hidden));
          }
          // hidden comments
          else if (child.id.startsWith("commentParentShow")) {
            // recursively parse hidden comments
            parsedComments.addAll(await parseCommentList(child, videoID, true));
          } else if (child.className.startsWith("nestedBlock")) {
            // reply comments
            List<UniversalComment> tempReplies = [];
            for (Element subChild in child.children) {
              if (subChild.className == "clearfix") {
                // replies can also have hidden comments, ignore the show button and directly parse the hidden comment
                if (subChild.children.length != 1) {
                  tempReplies.add(parseComment(
                      subChild.children.last.children.first, videoID, hidden));
                } else {
                  tempReplies.add(
                      parseComment(subChild.children.first, videoID, hidden));
                }
                // some comments are hidden with another load more button
                // Load and add them to the same list
              } else if (subChild.className ==
                  "commentBtn showMore viewRepliesBtn upperCase") {
                // the url is included in the button
                final repliesResponse = await http.get(Uri.parse(
                    "https://www.pornhub.com${subChild.attributes["data-ajax-url"]!}"));
                Document rawReplyComments = parse(repliesResponse.body);

                tempReplies.addAll(await parseCommentList(
                    rawReplyComments
                        .querySelector('div[class^="nestedBlock"]')!,
                    videoID,
                    hidden));
              }
            }
            // Add replyComments to previous top-level comment
            parsedComments.last.replyComments = tempReplies;
          }
          // Ignore "show hidden comments" buttons
          else if (child.className != "hiddenParentComments clearfix") {
            //logger.d("Unknown comment element: ${child.className}");
          }
        } catch (e, stacktrace) {
          logger
              .e("Error parsing comment. Continuing anyways: $e\n$stacktrace");
        }
      }

      // Counting comments is kinda hard, as normal, hidden and reply comments
      // are all in the same div...
      // TODO: Implement parsed comments vs received elements amount-based exception(s)

      return parsedComments;
    }

    // pornhub allows to get all comments in one go -> return empty list on second page
    if (page > 1) {
      return Future.value([]);
    }
    logger.i("Getting all comments for $videoID");

    // Each video has another id for the comments.
    // Get the video javascript
    String jscript =
        rawHtml.querySelector("#mobileContainer > script:nth-child(1)")!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(
        jscript.substring(jscript.indexOf("{"), jscript.indexOf('};') + 1));
    // While the id is usually a number, to make sure, convert it to String
    String internalCommentsID =
        jscriptMap["playbackTracking"]["video_id"].toString();

    Uri commentsUri = Uri.parse("https://www.pornhub.com/comment/show"
        "?id=$internalCommentsID"
        // not sure what exactly the upper limit is, but pornhub doesn't seem to throw an error
        "&limit=9999"
        // TODO: Implement comment sorting types
        "&popular=1"
        // This is required
        "&what=video"
        "&token=${_sessionCookies["token"]}");
    logger.d("Requesting comments URI: $commentsUri");
    final response = await http.get(commentsUri);

    if (response.statusCode != 200) {
      throw ("Http error for $commentsUri: ${response.statusCode} - ${response.reasonPhrase}");
    }

    Document rawComments = parse(response.body);

    List<UniversalComment> parsedComments = await parseCommentList(
        rawComments.querySelector("#cmtContent")!, videoID, false);

    return parsedComments;
  }
}