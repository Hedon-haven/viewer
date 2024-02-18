import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';

class XHamsterPlugin extends PluginBase {
  @override
  String pluginName = "xHamster.com";
  @override
  String apiUrl = "https://xhamster.com/";
  @override
  String videoEndpoint = "videos/";

  @override
  Future<UniversalSearchResult> convertSearchToUniversalFormat(
      Map searchJson) async {
    // TODO: implement convertSearchToUniversalFormat
    throw UnimplementedError();
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadataAsUniversalFormat(
      String videoId) async {
    var rawHtml = await requestHtml(apiUrl + videoEndpoint + videoId);
    // scrape values
    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href^="https://video"][as="fetch"][crossorigin]');
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
      print("Couldnt find m3u8 url");
      return UniversalVideoMetadata.error();
    } else {
      return UniversalVideoMetadata(
          m3u8Uri: Uri.parse(videoM3u8.attributes['href']!),
          title: videoTitle.text,
          pluginOrigin: this);
    }
  }
}

/// just for testing
void main() async {
  XHamsterPlugin hamster = XHamsterPlugin();
  var uniformat = await hamster.getVideoMetadataAsUniversalFormat("xh9oYwx");
  print(uniformat.m3u8Uri);
}
