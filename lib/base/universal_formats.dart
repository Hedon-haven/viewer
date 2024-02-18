import 'package:hedon_viewer/base/plugin_base.dart';

enum VideoResolution {
  unknown,
  below720,
  hd720,
  hd1080,
  hd4K,
  above4k,
}

enum SortingType {
  // relevance is usually the default type
  relevance,
  // Aka most recent
  date,
  views,
  rating,
  duration
}

enum Timeframe { allTime, currentDay, currentWeek, currentYear }

enum FramesPerSecond { unknown, belowThirty, thirty, sixty, aboveSixty }

class UniversalSearchRequest {
  final PluginBase? pluginOrigin;
  late String searchString;
  late FramesPerSecond fps;
  late VideoResolution minimalQuality;
  late int minimalDuration;
  late int maximalDuration;
  late List<String> categories;
  late SortingType sortingType;
  late Timeframe timeframe;
  late bool virtualReality;

  // make providing any values optional, even searchString
  UniversalSearchRequest({
    required this.pluginOrigin,
    String? searchString,
    FramesPerSecond? fps,
    VideoResolution? minimalQuality,
    int? minimalDuration,
    int? maximalDuration,
    List<String>? categories,
    SortingType? sortingType,
    Timeframe? timeframe,
    bool? virtualReality,
  })  : searchString = searchString ?? "",
        fps = fps ?? FramesPerSecond.unknown,
        minimalQuality = minimalQuality ?? VideoResolution.unknown,
        minimalDuration = minimalDuration ?? 0,
        maximalDuration = maximalDuration ?? -1,
        categories = categories ?? [],
        sortingType = sortingType ?? SortingType.relevance,
        timeframe = timeframe ?? Timeframe.allTime,
        virtualReality = virtualReality ?? false;
}

/// To make working with search results from different websites easier, every plugin must convert their results to this format
class UniversalSearchResult {
  // required values, with no defaults preset
  /// this id is later used to retrieve video metadata by the videoplayer
  final String videoID;
  final String title;
  final PluginBase? pluginOrigin;

  late Uri thumbnail;
  late Uri videoPreview;
  late int durationInSeconds;
  late int viewsTotal;
  late int ratingsPositivePercent;
  late VideoResolution maxQuality;

  UniversalSearchResult({
    required this.videoID,
    required this.title,
    required this.pluginOrigin,
    Uri? thumbnail,
    Uri? videoPreview,
    int? durationInSeconds,
    int? viewsTotal,
    int? ratingsPositivePercent,
    VideoResolution? maxQuality,
  })
  // TODO: Add no-thumbnail-image
  : thumbnail = thumbnail ?? Uri.parse("no_thumbnail"),
        videoPreview = videoPreview ?? Uri.parse(""),
        durationInSeconds = durationInSeconds ?? -1,
        viewsTotal = viewsTotal ?? -1,
        ratingsPositivePercent = ratingsPositivePercent ?? -1,
        maxQuality = maxQuality ?? VideoResolution.unknown;

  UniversalSearchResult.error()
      : title = "error",
        videoID = "error",
        pluginOrigin = null;
}

class UniversalVideoMetadata {
  final Uri m3u8Uri;
  final String title;
  final PluginBase? pluginOrigin;

  late String author;
  late String authorID;
  late List actors;
  late String description;
  late int viewsTotal;
  late List tags;
  late List categories;
  late DateTime uploadDate;
  late int ratingsPositiveTotal;
  late int ratingsNegativeTotal;
  late int ratingsTotal;

  UniversalVideoMetadata({
    required this.m3u8Uri,
    required this.title,
    required this.pluginOrigin,
    String? author,
    String? authorID,
    List? actors,
    String? description,
    int? viewsTotal,
    List? tags,
    List? categories,
    DateTime? uploadDate,
    int? ratingsPositiveTotal,
    int? ratingsNegativeTotal,
    int? ratingsTotal,
  })  : author = author ?? "",
        authorID = authorID ?? "",
        actors = actors ?? [],
        description = description ?? "",
        viewsTotal = viewsTotal ?? -1,
        tags = tags ?? [],
        categories = categories ?? [],
        uploadDate = uploadDate ?? DateTime.now(),
        ratingsPositiveTotal = ratingsPositiveTotal ?? -1,
        ratingsNegativeTotal = ratingsNegativeTotal ?? -1,
        ratingsTotal = ratingsTotal ?? -1;

  UniversalVideoMetadata.error()
      : m3u8Uri = Uri.parse("error"),
        title = "error",
        pluginOrigin = null;
}
