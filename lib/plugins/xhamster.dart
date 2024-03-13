import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';
import 'package:html/dom.dart';

class XHamsterPlugin extends PluginBase {
  @override
  String pluginName = "xHamster.com";
  @override
  String videoEndpoint = "https://xhamster.com/videos/";
  @override
  String searchEndpoint = "https://xhamster.com/search/";

  @override
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page) async {
    String encodedSearchString = Uri.encodeComponent(request.searchString);
    Document resultHtml =
        await requestHtml("$searchEndpoint$encodedSearchString?page=$page");
    List<Element>? resultsList = resultHtml
        .querySelector(".thumb-list")
        ?.querySelectorAll('div')
        .toList();

    // convert the divs into UniversalSearchResults
    if (resultsList == null) {
      return [];
    }
    List<UniversalSearchResult> results = [];
    for (Element resultDiv in resultsList) {
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

        Duration duration = const Duration(seconds: -1);
        if (durationList.length == 2) {
          duration = Duration(seconds: durationList[0] * 60 + durationList[1]);
          // if there is an hour in the duration
        } else if (durationList.length == 3) {
          duration = Duration(
              seconds: durationList[0] * 3600 +
                  durationList[1] * 60 +
                  durationList[2]);
        }

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
  Future<UniversalVideoMetadata> getVideoMetadata(String videoID) async {
    Document rawHtml = await requestHtml(videoEndpoint + videoID);

    String jscript = rawHtml.querySelector('#initials-script')!.text;

    // TODO: Maybe check if the m3u8 is a master m3u8
    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href*=".m3u8"][as="fetch"][crossorigin]');
    var videoTitle =
        rawHtml.querySelector('.with-player-container > h1:nth-child(1)');

    // ratings
    List<String> ratingRaw =
        rawHtml.querySelector(".rb-new__info")!.text.split(" / ");
    int ratingsPositive = int.parse(ratingRaw[0].replaceAll(",", ""));
    int ratingsNegative = int.parse(ratingRaw[1].replaceAll(",", ""));
    int ratingsTotal = ratingsPositive + ratingsNegative;

    // Inside the script element, find the views
    String viewsString = jscript.split('"views":').last;
    int viewsTotal =
        int.parse(viewsString.substring(0, viewsString.indexOf(',')));

    // author
    Element? authorRaw = rawHtml.querySelector(".video-tag--subscription");

    // Assume the account doesn't exist anymore
    String authorString = "Unavailable";
    String authorId = "unavailable";
    if (authorRaw != null) {
      // Most authors have a profile picture. However, those that do not, get a
      // Letter instead of their profile picture. This letter then gets caught
      // when the author name is extracted. The letter is an element inside the
      // main author element
      // => if it exists, remove it
      authorRaw.querySelector(".xh-avatar")?.remove();
      authorString = authorRaw.text.trim();
      authorId = authorRaw.attributes["href"]!.substring(30);
    }

    // actors
    // find the video tags container
    Element rawContainer =
        rawHtml.querySelector("#video-tags-list-container")!.children[0];
    // First element is always the author -> remove it
    rawContainer.children.removeAt(0);
    // remove the last element if its the overflow button
    if (rawContainer.children.last.children[0].attributes["class"] ==
        "xh-icon arrow-bottom-new icon-5f2e3") {
      rawContainer.children.removeLast();
    }
    // categories and actors are in the same list -> sort into two lists
    List<String> categories = [];
    List<String> actors = [];
    for (Element element in rawContainer.children) {
      if (element.children[0].attributes["href"]!
          .startsWith("https://xhamster.com/pornstars/")) {
        actors.add(element.children[0].text.trim());
      } else if (element.children[0].attributes["href"]!
          .startsWith("https://xhamster.com/categories/")) {
        categories.add(element.children[0].text.trim());
      }
    }

    // Inside the script element, find the date of the video
    String dateString = jscript.split('mlRelatedSnapshotId":"')[1];
    dateString = dateString.substring(0, dateString.indexOf('_'));

    // Convert to a format that DateTime can read
    // Convert to 20120227T132700 format
    dateString = dateString
        .replaceFirst("-", "")
        .replaceFirst("-", "")
        .replaceFirst("-", "T")
        .replaceAll("-", "");
    DateTime date = DateTime.parse(dateString);

    if (videoTitle == null ||
        videoM3u8 == null ||
        videoM3u8.attributes["href"] == null) {
      // TODO: add check for vr
      displayError("Couldnt find m3u8 url");
      return UniversalVideoMetadata.error();
    } else {
      // convert master m3u8 to list of media m3u8
      Map<int, Uri> m3u8Map =
          await parseM3U8(Uri.parse(videoM3u8.attributes["href"]!));
      return UniversalVideoMetadata(
          videoID: videoID,
          m3u8Uris: m3u8Map,
          title: videoTitle.text,
          pluginOrigin: this,
          author: authorString,
          authorID: authorId,
          actors: actors,
          description:
              rawHtml.querySelector(".ab-info > p:nth-child(1)")?.text ??
                  "No description",
          viewsTotal: viewsTotal,
          // xhamster does not have tags
          categories: categories,
          uploadDate: date,
          ratingsPositiveTotal: ratingsPositive,
          ratingsNegativeTotal: ratingsNegative,
          ratingsTotal: ratingsTotal,
          virtualReality: false);
    }
  }
}
