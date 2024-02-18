// There is a universal m3u8 and separate for each quality in the initial html. Just find them. Gotta remove the backslashes from the link too.

import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';

class PornhubPlugin extends PluginBase {
  @override
  String pluginName = "Pornhub.com";
  String apiUrl = "https://pornhub.com/";

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
          title: videoTitle.text,
          pluginOrigin: this);
    }
  }
}

/// just for testing
void main() async {
  PornHubPlugin phub = PornHubPlugin();
  var uniformat = await phub.getVideoMetadataAsUniversalFormat("xhWEGdf");
  print(uniformat.m3u8Uri);
}
