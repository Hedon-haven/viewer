import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:html/dom.dart';

class XHamsterPlugin extends PluginBase {
  @override
  String pluginName = "xHamster.com";
  String apiUrl = "https://xhamster.com/";
  String videoEndpoint = "videos/";
  String searchEndpoint = "search/";

  @override
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page) async {
    String encodedSearchString = Uri.encodeComponent(request.searchString);
    Document resultHtml = await requestHtml(
        "$apiUrl$searchEndpoint$encodedSearchString?page=$page");
    List<Element>? resultsList = resultHtml
        .querySelector(".thumb-list")
        ?.querySelectorAll('div')
        .toList();

    // convert the divs into UniversalSearchResults
    if (resultsList == null) {
      return [];
    }
    List<UniversalSearchResult> results = [];
    for (var resultDiv in resultsList) {
      // Only select the divs with <div class="thumb-list__item video-thumb"
      if (resultDiv.attributes['class']?.trim() ==
          "thumb-list__item video-thumb") {
        // each result has 2 sub-divs
        List<Element>? subElements = resultDiv.children;

        String? thumbnail =
            subElements[0].querySelector('img')?.attributes['src'];
        String? videoPreview = subElements[0].attributes['data-previewvideo'];
        String? iD = subElements[0].attributes['href']?.split("/").last;
        String? title = subElements[1].querySelector('a')?.attributes['title'];
        // convert time string into int list
        List<int> durationList = subElements[0]
            .querySelector('div[class="thumb-image-container__duration"]')!
            .text
            .trim()
            .split(":")
            .map((e) => int.parse(e))
            .toList();
        int duration = durationList[0] * 60 + durationList[1];

        // determine video resolution
        VideoResolution resolution = VideoResolution.unknown;
        bool virtualReality = false;
        if (subElements[0].querySelector('i[class^="xh-icon"]') != null) {
          switch (subElements[0]
              .querySelector('i[class^="xh-icon"]')!
              .attributes['class']!
              .split(" ")[1]) {
            case "beta-thumb-hd":
              resolution = VideoResolution.hd720;
            // TODO: Maybe somehow determine 1080p support?
            case "beta-thumb-uhd":
              resolution = VideoResolution.hd4K;
            case "beta-thumb-vr":
              resolution = VideoResolution.unknown;
              virtualReality = true;
          }
        } else {
          resolution = VideoResolution.below720;
        }

        // determine video views
        int views = 0;
        String viewsString = subElements[1]
            .querySelector("div[class='video-thumb-views']")!
            .text
            .trim()
            .split(" views")[0];

        // just added means 0, means skip the whole part coz views is already 0
        if (viewsString != "just added") {
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

        results.add(UniversalSearchResult(
          videoID: iD ?? "",
          title: title ?? "",
          pluginOrigin: this,
          thumbnail: thumbnail,
          videoPreview: videoPreview != null ? Uri.parse(videoPreview) : null,
          durationInSeconds: duration,
          viewsTotal: views,
          // TODO: Find a way to determine ratings (dont seem to be in the html)
          maxQuality: resolution,
          virtualReality: virtualReality,
        ));
      }
    }

    return results;
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadataAsUniversalFormat(
      String videoId) async {
    var rawHtml = await requestHtml(apiUrl + videoEndpoint + videoId);
    // scrape values
    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href*="master.m3u8"][as="fetch"][crossorigin]');
    var videoTitle =
        rawHtml.querySelector('.with-player-container > h1:nth-child(1)');

    // ratings
    var ratingRaw = rawHtml.querySelector(".rb-new__info");
    var ratingsPositive =
        int.parse(ratingRaw!.text.split(" / ")[0].replaceAll(",", ""));
    var ratingsNegative =
        int.parse(ratingRaw.text.split(" / ")[1].replaceAll(",", ""));
    var ratingsTotal = ratingsPositive + ratingsNegative;

    // author
    var authorRaw = rawHtml.querySelector(".video-tag--subscription");
    // Most authors have a profile picture. However, those that do not, get a
    // Letter instead of their profile picture. This letter then gets caught
    // when the author name is extracted. The letter is an element inside the
    // main author element
    // => if it exists, remove it
    authorRaw?.querySelector(".xh-avatar")?.remove();
    var authorString = authorRaw?.text.trim();
    var authorId = authorRaw?.attributes["href"]?.substring(27);

    // actors
    // find the video tags container
    var rawContainer = rawHtml.querySelector("#video-tags-list-container");

    if (videoTitle == null ||
        videoM3u8 == null ||
        videoM3u8.attributes["href"] == null) {
      displayError("Couldnt find m3u8 url");
      return UniversalVideoMetadata.error();
    } else {
      // convert master m3u8 to list of media m3u8
      var m3u8Map = await parseM3U8(Uri.parse(videoM3u8.attributes["href"]!));
      return UniversalVideoMetadata(
          m3u8Uris: m3u8Map,
          title: videoTitle.text,
          pluginOrigin: this);
    }
  }
}
