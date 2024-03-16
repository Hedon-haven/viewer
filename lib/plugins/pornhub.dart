// There is a universal m3u8 and separate for each quality in the initial html. Just find them. Gotta remove the backslashes from the link too.

import 'dart:developer';

import 'package:hedon_viewer/base/plugin_base.dart';
import 'package:hedon_viewer/base/universal_formats.dart';

class PornhubPlugin extends PluginBase {
  @override
  String pluginName = "Pornhub.com";
  String apiUrl = "https://pornhub.com/";
  String videoEndpoint = "view_video.php?viewkey=";

  @override
  Future<List<UniversalSearchResult>> search(
      UniversalSearchRequest request, int page) {
    // TODO: implement search
    throw UnimplementedError();
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(
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
          title: videoTitle.text,
          pluginOrigin: this, videoID: '', m3u8Uris: {});
    }
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) {
    // TODO: implement getSearchSuggestions
    throw UnimplementedError();
  }
}

/// just for testing
void main() async {
  PornhubPlugin phub = PornhubPlugin();
  var uniformat = await phub.getVideoMetadata("xhWEGdf");
  log(uniformat.m3u8Uris as String);
}
