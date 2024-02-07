import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';

class XHamsterPlugin extends PluginBase {
  static String apiUrl = "https://xhamster.com/";
  static String videoEndpoint = "videos/";

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
    var videoTitle =
        rawHtml.querySelector('.with-player-container > h1:nth-child(1)');

    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href^="https://video-b.xhcdn.com"][as="fetch"][crossorigin]');

    if (videoTitle == null ||
        videoM3u8 == null ||
        videoM3u8.attributes['href'] == null) {
      return UniversalVideoMetadata.error();
    } else {
      return UniversalVideoMetadata(
          m3u8Uri: Uri.parse(videoM3u8.attributes['href']!),
          title: videoTitle.text);
    }
  }
}

/// just for testing
void main() async {
  XHamsterPlugin hamster = XHamsterPlugin();
  var uniformat = await hamster.getVideoMetadataAsUniversalFormat("xhWEGdf");
  print(uniformat.m3u8Uri);
}
