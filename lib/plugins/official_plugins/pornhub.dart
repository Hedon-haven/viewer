import 'dart:convert';

import 'package:hedon_viewer/backend/plugin_interface.dart';
import 'package:hedon_viewer/backend/universal_formats.dart';
import 'package:html/dom.dart';

import 'official_plugin_base.dart';

class PornhubPlugin extends PluginBase implements PluginInterface {
  @override
  String name = "Pornhub.com";
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
      UniversalSearchRequest sr, int page) async {
    String encodedSearchString = Uri.encodeComponent(sr.searchString);
    // @formatter:off
    // Pornhub does not accept redundant search parameters.
    // For example passing &min_duration=0 will result in a 404, even though technically 0 is the default duration in the website's ui
    // ignore: prefer_interpolation_to_compose_strings
    String urlString = searchEndpoint + encodedSearchString
        + "&page=$page"
        + sortingTypeMap[sr.sortingType]!
        // only top rated and most views support sorting by date
        + (sr.sortingType == "Rating" || sr.sortingType == "Views" ? dateRangeMap[sr.dateRange]!: "")
        // pornhub considers 720p to be hd. No further narrowing is possible in the url
        + (sr.minQuality >= 720 ? "&hd=1" : "")
        + minDurationMap[sr.minDuration]!
        + maxDurationMap[sr.maxDuration]!
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
        Duration duration = const Duration(seconds: -1);
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
        int views = 0;
        String? viewsString = resultDiv
            .querySelector('span[class="views"]')
            ?.querySelector("var")
            ?.text;

        // just added means 0, means skip the whole part coz views is already 0
        if (viewsString != "just added" && viewsString != null) {
          if (viewsString.endsWith("K")) {
            if (viewsString.contains(".")) {
              views = int.parse(viewsString.split(".")[1][0]) * 100;
              // this is so that the normal step still works
              viewsString = viewsString.split(".")[0] + " ";
            }
            views +=
                int.parse(viewsString.substring(0, viewsString.length - 1)) *
                    1000;
          } else if (viewsString.endsWith("M")) {
            if (viewsString.contains(".")) {
              views = int.parse(viewsString.split(".")[1][0]) * 100000;
              // this is so that the normal step still works
              viewsString = viewsString.split(".")[0] + " ";
            }
            views +=
                int.parse(viewsString.substring(0, viewsString.length - 1)) *
                    1000000;
          } else {
            views = int.parse(viewsString);
          }
        }

        String? ratingsString = resultDiv
            .querySelector('div[class="rating-container neutral"]')
            ?.querySelector("div")
            ?.text
            .trim();
        int ratings = -1;
        if (ratingsString != null) {
          ratings =
              int.parse(ratingsString.substring(0, ratingsString.length - 1));
        }

        // TODO: determine video resolution
        // pornhub only offers up to 1080p

        results.add(UniversalSearchResult(
          videoID: iD ?? "-",
          title: title ?? "-",
          plugin: this,
          author: author ?? "-",
          // All authors on pornhub are verified
          verifiedAuthor: true,
          thumbnail: thumbnail,
          videoPreview: videoPreview != null ? Uri.parse(videoPreview) : null,
          duration: duration,
          viewsTotal: views,
          ratingsPositivePercent: ratings,
          maxQuality: null,
          virtualReality: virtualReality,
        ));
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
    int? ratingsPositive = -1;
    String? ratingsPositiveString =
        rawHtml.querySelector('span[class="votesUp"]')?.text;
    if (ratingsPositiveString != null) {
      if (ratingsPositiveString.endsWith("K")) {
        ratingsPositive = int.parse(ratingsPositiveString.substring(
                0, ratingsPositiveString.length - 1)) *
            1000;
      } else {
        ratingsPositive = int.parse(ratingsPositiveString);
      }
    }

    int? ratingsNegative = -1;
    String? ratingsNegativeString =
        rawHtml.querySelector('span[class="votesUp"]')?.text;
    if (ratingsNegativeString != null) {
      if (ratingsNegativeString.endsWith("K")) {
        ratingsNegative = int.parse(ratingsNegativeString.substring(
                0, ratingsNegativeString.length - 1)) *
            1000;
      } else {
        ratingsNegative = int.parse(ratingsNegativeString);
      }
    }

    int ratingsTotal = ratingsPositive + ratingsNegative;

    // convert views string into views total int
    int? viewsTotal = -1;
    int viewsDecimal = 0;
    String? viewsString = rawHtml
        .querySelector('div[class="ratingInfo"]')
        ?.querySelector('div[class="views"]')
        ?.querySelector("span")
        ?.text;

    if (viewsString != null) {
      if (viewsString.contains(".")) {
        // round to the nearest 100
        viewsDecimal = int.parse(viewsString.split(".")[1][0]) * 100;
        // remove from the string
        viewsString = viewsString.split(".")[0] + " ";
      }
      if (viewsString.endsWith("K")) {
        logger.d("trying to parse:${viewsString.substring(0, viewsString.length - 1)}");
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

    List<String> actors = [];
    if (actorsList != null) {
      for (Element element in actorsList) {
        actors.add(element.text);
      }
    }

    // categories
    List<Element>? categoriesList = rawHtml
        .querySelector('div[class="categoriesWrapper"]')
        ?.querySelectorAll("a");

    List<String> categories = [];
    if (categoriesList != null) {
      for (Element element in categoriesList) {
        categories.add(element.text);
      }
    }

    // TODO: Either find actual date or convert apprx date given by pornhub to unix
    DateTime date = DateTime.utc(1970, 1, 1);

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

    return UniversalVideoMetadata(
        videoID: videoId,
        m3u8Uris: m3u8Map,
        title: jscriptMap["video_title"],
        plugin: this,
        author: authorString,
        authorID: authorId,
        actors: actors,
        description: rawHtml.querySelector(".ab-info > p:nth-child(1)")?.text ??
            "No description",
        viewsTotal: viewsTotal,
        // xhamster does not have tags
        categories: categories,
        uploadDate: date,
        ratingsPositiveTotal: ratingsPositive,
        ratingsNegativeTotal: ratingsNegative,
        ratingsTotal: ratingsTotal,
        virtualReality: jscriptMap["isVR"] == 1);
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) {
    // TODO: implement getSearchSuggestions
    throw UnimplementedError();
  }

  @override
  bool checkAndLoadFromConfig(String configPath) {
    // As this is an official plugin, it doesn't need to be loaded from a file
    return true;
  }
}
