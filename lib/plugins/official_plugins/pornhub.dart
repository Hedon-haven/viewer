import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';

import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import '/plugins/official_plugins/official_plugin_base.dart';

class PornhubPlugin extends PluginBase implements PluginInterface {
  @override
  bool isOfficialPlugin = true;
  @override
  String codeName = "pornhub-official";
  @override
  String prettyName = "Pornhub.com";
  @override
  Uri iconUrl = Uri.parse("https://www.pornhub.com/favicon.ico");
  @override
  String providerUrl = "https://www.pornhub.com";
  @override
  String videoEndpoint = "https://www.pornhub.com/view_video.php?viewkey=";
  @override
  String searchEndpoint = "https://www.pornhub.com/video/search?search=";
  @override
  int initialHomePage = 0;
  @override
  int initialSearchPage = 1;
  @override
  int initialCommentsPage = 1;
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
  double version = 1.0;

  @override
  Map<String, String> sessionCookies = {};

  // Names maps
  @override
  Map<String, String> sortingTypeMap = {
    "Relevance": "",
    "Upload date": "&o=mr",
    "Views": "&o=mv",
    "Rating": "&o=tr",
    "Duration": "&o=lg"
  };
  @override
  Map<String, String> dateRangeMap = {
    "All time": "",
    "Last year": "&t=y",
    "Last month": "&t=m",
    "Last week": "&t=w",
    "Last day/Last 3 days/Latest": "&t=t"
  };
  @override
  Map<int, String> minDurationMap = {
    0: "",
    5: "", // pornhub doesnt support 5 min -> use 0
    10: "&min_duration=10",
    20: "&min_duration=20",
    30: "&min_duration=30",
    60: ""
  };
  @override
  Map<int, String> maxDurationMap = {
    0: "",
    300: "", // pornhub doesnt support 5 min -> use 0
    600: "&max_duration=10",
    1200: "&max_duration=20",
    1800: "&max_duration=30",
    3600: ""
  };

  @override
  Future<List<UniversalSearchResult>> getHomePage(int page) async {
    List<Element>? resultsList;
    if (page == 0) {
      // page=0 returns a different page than requesting the base website
      Document resultHtml = await requestHtml(providerUrl);
      resultsList = resultHtml
          // the base page has a different id for the video list
          .querySelector('ul[id="singleFeedSection"]')
          ?.querySelectorAll('li[class^="pcVideoListItem"]')
          .toList();
    } else {
      Document resultHtml = await requestHtml("$providerUrl/video?page=$page");
      resultsList = resultHtml
          .querySelector('ul[id="videoCategory"]')
          ?.querySelectorAll('li[class^="pcVideoListItem"]')
          .toList();
    }
    return parseVideoPage(resultsList!);
  }

  @override
  Future<List<UniversalSearchResult>> getSearchResults(
      UniversalSearchRequest request, int page) async {
    String encodedSearchString = Uri.encodeComponent(request.searchString);
    // @formatter:off
    // Pornhub does not accept redundant search parameters.
    // For example passing &min_duration=0 will result in a 404, even though technically 0 is the default duration in the website's ui
    // ignore: prefer_interpolation_to_compose_strings
    String urlString = searchEndpoint + encodedSearchString
        + "&page=$page"
        + sortingTypeMap[request.sortingType]!
        // only top rated and most views support sorting by date
        + (request.sortingType == "Rating" || request.sortingType == "Views" ? dateRangeMap[request.dateRange]!: "")
        // pornhub considers 720p to be hd. No further narrowing is possible in the url
        + (request.minQuality >= 720 ? "&hd=1" : "")
        + minDurationMap[request.minDuration]!
        + maxDurationMap[request.maxDuration]!
    ;
    // @formatter:on

    Document resultHtml = await requestHtml(urlString);
    if (resultHtml.outerHtml == "<html><head></head><body></body></html>") {
      return [];
    }
    List<Element>? resultsList = resultHtml
        .querySelector('ul[id="videoSearchResult"]')
        ?.querySelectorAll('li[class^="pcVideoListItem"]')
        .toList();
    return parseVideoPage(resultsList!);
  }

  Future<List<UniversalSearchResult>> parseVideoPage(
      List<Element> resultsList) async {
    // convert the divs into UniversalSearchResults
    List<UniversalSearchResult> results = [];
    for (Element resultElement in resultsList) {
      try {
        String? iD = resultElement.attributes['data-video-vkey'];

        Element resultDiv = resultElement.querySelector("div")!;

        // first div is phimage
        Element? imageDiv =
            resultDiv.querySelector("div[class=phimage]")?.querySelector("a");
        String? thumbnail = imageDiv?.querySelector("img")?.attributes["src"];
        String? videoPreview =
            imageDiv?.querySelector("img")?.attributes["data-mediabook"];

        // convert time string into int list
        // pornhub automatically converts hours into minutes -> no need to check
        List<int>? durationList = imageDiv
            ?.querySelector('div[class="marker-overlays js-noFade"]')
            ?.querySelector("var")!
            .text
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
        if (imageDiv
                ?.querySelector('div[class="marker-overlays js-noFade"]')
                ?.querySelector('span[class="hd-thumbnail vr-thumbnail"]') !=
            null) {
          virtualReality = true;
        }

        // the title field can have different names
        String? title = resultDiv
                .querySelector('a[class="thumbnailTitle "]')
                ?.attributes["title"]
                ?.trim() ??
            resultDiv
                .querySelector('a[class="gtm-event-thumb-click"]')
                ?.attributes["title"]
                ?.trim();

        // the author field can have different names
        String? author =
            resultDiv.querySelector('div[class="usernameWrap"]')?.text.trim() ??
                resultDiv
                    .querySelector('div[class="usernameBadgesWrapper"]')
                    ?.text
                    .trim();

        // determine video views
        int? views;
        String? viewsString = resultDiv
            .querySelector('span[class="views"]')
            ?.querySelector("var")
            ?.text;

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
            .querySelector('div[class="rating-container neutral"]')
            ?.querySelector("div")
            ?.text
            .trim();
        int? ratings;
        if (ratingsString != null) {
          ratings =
              int.parse(ratingsString.substring(0, ratingsString.length - 1));
        }

        // TODO: determine video resolution
        // pornhub only offers up to 1080p

        UniversalSearchResult uniResult = UniversalSearchResult(
          videoID: iD ?? "-",
          title: title ?? "-",
          plugin: this,
          thumbnail: thumbnail,
          videoPreview: videoPreview != null ? Uri.parse(videoPreview) : null,
          duration: duration,
          viewsTotal: views,
          ratingsPositivePercent: ratings,
          maxQuality: null,
          virtualReality: virtualReality,
          author: author,
          // All authors on pornhub are verified
          verifiedAuthor: true,
        );

        // print warnings if some data is missing
        uniResult.printNullKeys(codeName,
            ["thumbnailBinary", "lastWatched", "firstWatched", "maxQuality"]);

        results.add(uniResult);
      } catch (e) {
        displayError("Failed to scrape video result: $e");
      }
    }

    return results;
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(String videoId) async {
    Document rawHtml = await requestHtml(videoEndpoint + videoId);

    // Get the video javascript and convert the main json into a map
    String jscript =
        rawHtml.querySelector("#player > script:nth-child(1)")!.text;
    Map<String, dynamic> jscriptMap = jsonDecode(jscript.substring(
        jscript.indexOf("{"),
        jscript.lastIndexOf('autoFullscreen":true};') + 21));

    // ratings
    int? ratingsPositive;
    String? ratingsPositiveString =
        rawHtml.querySelector('span[class="votesUp"]')?.text;
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
    String? ratingsNegativeString =
        rawHtml.querySelector('span[class="votesDown"]')?.text;
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
    if (ratingsPositive != null || ratingsNegative != null) {
      ratingsTotal = ratingsPositive! + ratingsNegative!;
    }

    // convert views string into views total int
    int? viewsTotal;
    String? viewsString = rawHtml
        .querySelector('div[class="ratingInfo"]')
        ?.querySelector('div[class="views"]')
        ?.querySelector("span")
        ?.text;

    if (viewsString != null) {
      viewsTotal = 0;
      int viewsDecimal = 0;
      if (viewsString.contains(".")) {
        // round to the nearest 100
        viewsDecimal = int.parse(viewsString.split(".")[1][0]) * 100;
        // remove from the string
        // ignore: prefer_interpolation_to_compose_strings
        viewsString = viewsString.split(".")[0] + " ";
      }
      if (viewsString.endsWith("K")) {
        logger.d(
            "trying to parse views: ${viewsString.substring(0, viewsString.length - 1)}");
        viewsTotal =
            int.parse(viewsString.substring(0, viewsString.length - 1)) * 1000;
      } else if (viewsString.endsWith("M")) {
        viewsTotal =
            int.parse(viewsString.substring(0, viewsString.length - 1)) *
                1000000;
      } else {
        viewsTotal = int.parse(viewsString);
      }
      viewsTotal += viewsDecimal;
    }

    // author
    Element? authorRaw = rawHtml
        .querySelector('span[class="usernameBadgesWrapper"]')
        ?.querySelector("a");

    String? authorString = authorRaw?.text;
    String? authorId = authorRaw?.attributes["href"];

    // actors
    List<Element>? actorsList = rawHtml
        .querySelector('div[class="pornstarsWrapper js-pornstarsWrapper"]')
        ?.querySelectorAll("a");

    List<String>? actors = [];
    if (actorsList != null) {
      for (Element element in actorsList) {
        actors.add(element.text);
      }
    }
    if (actors.isEmpty) {
      actors = null;
    }

    // categories
    List<Element>? categoriesList = rawHtml
        .querySelector('div[class="categoriesWrapper"]')
        ?.querySelectorAll("a");

    List<String>? categories = [];
    if (categoriesList != null) {
      for (Element element in categoriesList) {
        categories.add(element.text);
      }
    }
    if (categories.isEmpty) {
      categories = null;
    }

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
        title: jscriptMap["video_title"] ?? "-",
        plugin: this,
        author: authorString,
        authorID: authorId,
        actors: actors,
        description: rawHtml
            .querySelector('div[class="video-info-row"]')
            ?.text
            .trim()
            .replaceAll("Description: ", ""),
        viewsTotal: viewsTotal,
        tags: null,
        categories: categories,
        // TODO: Either find actual date or convert approx date given by pornhub to unix
        uploadDate: null,
        ratingsPositiveTotal: ratingsPositive,
        ratingsNegativeTotal: ratingsNegative,
        ratingsTotal: ratingsTotal,
        virtualReality: jscriptMap["isVR"] == 1,
        chapters: null,
        rawHtml: rawHtml);

    // print warnings if some data is missing
    metadata.printNullKeys(
        codeName, ["tags", "uploadDate", "chapters", "description"]);

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
    final rawHtml = message[3] as Document;

    // Not quite sure what this is needed for, but fails otherwise
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    // Get the video javascript
    String jscript =
        rawHtml.querySelector("#player > script:nth-child(1)")!.text;

    // Extract the progressImage url from jscript
    int startIndex = jscript.indexOf('"urlPattern":"') + 14;
    int endIndex = jscript.substring(startIndex).indexOf('","');
    String imageUrl = jscript.substring(startIndex, startIndex + endIndex);

    // Extract the sampling frequency
    int startIndexFrequency = jscript.indexOf('"samplingFrequency":') + 20;
    logger.d("Start index frequency: $startIndexFrequency");
    int endIndexFrequency =
        jscript.substring(startIndexFrequency).indexOf(',"');
    logger.d("End index frequency: $endIndexFrequency");
    logger.d(
        "Trying to parse into an int: ${jscript.substring(startIndexFrequency, startIndexFrequency + endIndexFrequency)}");
    int samplingFrequency = int.parse(jscript.substring(
        startIndexFrequency, startIndexFrequency + endIndexFrequency));

    String imageBuildUrl = imageUrl.replaceAll("\\/", "/");
    logger.d(imageBuildUrl);
    String suffix = ".${imageBuildUrl.split(".").last}";
    logger.d(suffix);
    int lastImageIndex =
        int.parse(imageBuildUrl.split("{").last.split("}").first);
    logger.d(lastImageIndex);
    String baseUrl = imageBuildUrl.split("{").first;
    logger.d(baseUrl);

    logger.i("Downloading and processing progress images");
    List<List<Uint8List>> allThumbnails =
        List.generate(lastImageIndex + 1, (_) => []);
    List<Future<void>> imageFutures = [];

    for (int i = 0; i <= lastImageIndex; i++) {
      // Create a future for downloading and processing
      imageFutures.add(Future(() async {
        logger.d("Preparing to download $baseUrl$i$suffix");
        Uint8List image =
            await downloadThumbnail(Uri.parse("$baseUrl$i$suffix"));
        logger.d("Cutting image $baseUrl$i$suffix into progress images");
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
                firstThumbnail = encodeJpg(
                    copyCrop(decodedImage, x: w, y: h, width: 160, height: 90));
                thumbnails.add(firstThumbnail); // Add the first encoded image
              } else {
                // Reuse the reference to the first thumbnail
                thumbnails.add(firstThumbnail);
              }
            }
          }
        }
        allThumbnails[i] = thumbnails;
        logger.d("Completed processing $baseUrl$i$suffix");
      }));
    }
    // Await all futures
    await Future.wait(imageFutures);

    // Combine all results into single, chronological list
    logger.d("Combining all results into single, chronological list");
    List<Uint8List> completedProcessedImages =
        allThumbnails.expand((x) => x).toList();

    logger.i("Completed processing all images");
    // return the completed processed images through the separate resultsPort
    logger.d(
        "Sending ${completedProcessedImages.length} progress images to main process");
    resultsPort.send(completedProcessedImages);
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) async {
    logger.d("Getting search suggestions for $searchString");
    final response = await http.get(
        Uri.parse(
            "https://www.pornhub.com/video/search_autocomplete?&token=${sessionCookies["token"]}&q=$searchString"),
        headers: {"Cookie": "ss=${sessionCookies["ss"]}"});
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
  bool checkAndLoadFromConfig(String configPath) {
    // As this is an official plugin, it doesn't need to be loaded from a file
    return true;
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
          sessionCookies["ss"] =
              cookiesList[i].substring(3, cookiesList[i].indexOf(";"));
          logger.i("Session cookie: ${sessionCookies["ss"]}");
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
      sessionCookies["token"] = tokenHtml.substring(
          tokenHtml.indexOf('= "') + 3, tokenHtml.indexOf('",'));
      logger.i("Token: ${sessionCookies["token"]}");
    } else {
      logger.e("No token received or found; couldn't extract token");
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  bool runFunctionalityTest() {
    // TODO: Implement proper init test for pornhub plugin
    return true;
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
    } catch (e) {
      logger.w("Error converting date string to DateTime: $e");
      return null;
    }
    return converted;
  }

  UniversalComment _parseComment(Element comment, String videoID, bool hidden) {
    Element tempComment = comment.children.first;
    return UniversalComment(
        videoID: videoID,
        author: tempComment
                .querySelector('img[class="commentAvatarImg avatarTrigger"]')
                ?.attributes["title"] ??
            "Couldn't scrape comment author. Please report this",
        commentBody: tempComment
                .querySelector("div[class=commentMessage]")
                ?.children
                .first
                .text
                .trim() ??
            "Couldn't scrape comment body. Please report this",
        hidden: hidden,
        plugin: this,
        authorID: tempComment
            .querySelector('a[class="userLink clearfix"]')
            ?.attributes["href"]
            ?.substring(7),
        commentID: comment.className.split(" ")[2].replaceAll("commentTag", ""),
        profilePicture: tempComment
            .querySelector('img[class="commentAvatarImg avatarTrigger"]')
            ?.attributes["src"],
        ratingsTotal: int.tryParse(
            tempComment.querySelector('span[class*="voteTotal"]')?.text ?? ""),
        commentDate: _convertStringToDateTime(
            tempComment.querySelector('div[class="date"]')?.text.trim()));
  }

  /// Recursive function
  // TODO: Parallelize, but keep in mind that reply comments need to be able to be added to the prev top-level comment
  Future<List<UniversalComment>> _parseCommentList(
      Element parent, String videoID, bool hidden) async {
    List<UniversalComment> parsedComments = [];
    for (Element child in parent.children) {
      // normal / top-level comment
      if (child.className.startsWith("commentBlock")) {
        parsedComments.add(_parseComment(child, videoID, hidden));
      }
      // hidden comments
      else if (child.id.startsWith("commentParentShow")) {
        // recursively parse hidden comments
        parsedComments.addAll(await _parseCommentList(child, videoID, true));
      } else if (child.className.startsWith("nestedBlock")) {
        // reply comments
        List<UniversalComment> tempReplies = [];
        for (Element subChild in child.children) {
          if (subChild.className == "clearfix") {
            // replies can also have hidden comments, ignore the show button and directly parse the hidden comment
            if (subChild.children.length != 1) {
              tempReplies.add(_parseComment(
                  subChild.children.last.children.first, videoID, hidden));
            } else {
              tempReplies
                  .add(_parseComment(subChild.children.first, videoID, hidden));
            }
            // some comments are hidden with another load more button
            // Load and add them to the same list
          } else if (subChild.className ==
              "commentBtn showMore viewRepliesBtn upperCase") {
            // the url is included in the button
            final repliesResponse = await http.get(Uri.parse(
                "https://www.pornhub.com${subChild.attributes["data-ajax-url"]!}"));
            Document rawReplyComments = parse(repliesResponse.body);

            tempReplies.addAll(await _parseCommentList(
                rawReplyComments.querySelector('div[class^="nestedBlock"]')!,
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
    }
    return parsedComments;
  }

  @override
  // TODO: implement getComments for pornhub
  Future<List<UniversalComment>> getComments(
      String videoID, Document rawHtml, int page) async {
    // pornhub allows to get all comments in one go -> return empty list on second page
    if (page > 1) {
      return Future.value([]);
    }
    logger.i("Getting all comments for $videoID");

    // Each video has another id for the comments.
    String jscript =
        rawHtml.querySelector("#player > script:nth-child(1)")!.text.trim();
    String internalCommentsID = jscript.substring(
        jscript.indexOf("var flashvars_") + 14, jscript.indexOf(" = {"));

    final response = await http.get(Uri.parse(
        "https://www.pornhub.com/comment/show"
        "?id=$internalCommentsID"
        // not sure what exactly the upper limit is, but pornhub doesn't seem to throw an error
        "&limit=9999"
        // TODO: Implement comment sorting types
        "&popular=1"
        // This is required
        "&what=video"
        "&token=${sessionCookies["token"]}"));
    Document rawComments = parse(response.body);

    List<UniversalComment> parsedComments = await _parseCommentList(
        rawComments.querySelector("#cmtContent")!, videoID, false);

    return parsedComments;
  }
}