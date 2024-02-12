import 'package:hedon_viewer/base/plugin_base.dart';

enum VideoResolution {
  unknown,
  below720,
  hd720,
  hd1080,
  hd4K,
  above4k,
}

/// To make working with search results from different websites easier, every plugin must convert their results to this format
class UniversalSearchResult {
  // required values, with no defaults preset
  /// this id is later used to retrieve video metadata by the videoplayer
  final String videoID;
  final String title;
  final PluginBase? pluginOrigin;

  // optional values with defaults
  // TODO: Add no-thumbnail-image
  late Uri thumbnail = Uri.parse("no_thumbnail");
  late List<Uri> previewThumbnails = [];
  late int durationInSeconds = -1;
  late int viewsTotal = -1;
  late int ratingsPositivePercent = -1;
  late VideoResolution maxQuality = VideoResolution.unknown;

  UniversalSearchResult(
      this.thumbnail,
      this.previewThumbnails,
      this.durationInSeconds,
      this.viewsTotal,
      this.ratingsPositivePercent,
      this.maxQuality,
      {required this.title,
      required this.videoID,
      required this.pluginOrigin});

  UniversalSearchResult.error()
      : title = "error",
        videoID = "error",
        pluginOrigin = null;
}

class UniversalVideoMetadata {
  final Uri m3u8Uri;
  final String title;
  late String author = "";
  late String authorID = "";
  late List actors = [];
  late String description = "";
  late int viewsTotal = -1;
  late List tags = [];
  late List categories = [];
  late DateTime uploadDate = DateTime.now();

  late int ratingsPositiveTotal = -1;
  late int ratingsNegativeTotal = -1;
  late int ratingsTotal = -1;

  UniversalVideoMetadata({required this.m3u8Uri, required this.title});

  UniversalVideoMetadata.error()
      : m3u8Uri = Uri.parse("error"),
        title = "error";
}
