import 'package:hedon_viewer/backend/plugin_base.dart';

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


class UniversalSearchRequest {
  late String searchString;
  late int minimalFramesPerSecond;
  late int minimalQuality;
  late int minimalDuration;
  late int maximalDuration;
  late List<String> categories;
  late SortingType sortingType;
  late Timeframe timeframe;
  late bool virtualReality;

  // make providing any values optional, even searchString
  UniversalSearchRequest({
    String? searchString,
    int? minimalFramesPerSecond,
    int? minimalQuality,
    int? minimalDuration,
    int? maximalDuration,
    List<String>? categories,
    SortingType? sortingType,
    Timeframe? timeframe,
    bool? virtualReality,
  })  : searchString = searchString ?? "",
        minimalFramesPerSecond = minimalFramesPerSecond ?? -1,
        minimalQuality = minimalQuality ?? -1,
        minimalDuration = minimalDuration ?? 0,
        maximalDuration = maximalDuration ?? -1,
        categories = categories ?? [],
        sortingType = sortingType ?? SortingType.relevance,
        timeframe = timeframe ?? Timeframe.allTime,
        virtualReality = virtualReality ?? false;

  /// Returns the entire UniversalVideoMetadata in a map. Only used for testing
  Map<String, dynamic> convertToMap() {
    return {
      "searchString": searchString,
      "minimalFramesPerSecond": minimalFramesPerSecond,
      "minimalQuality": minimalQuality,
      "minimalDuration": minimalDuration,
      "maximalDuration": maximalDuration,
      "categories": categories,
      "sortingType": sortingType,
      "timeframe": timeframe,
      "virtualReality": virtualReality
    };
  }

  /// Return the entire  UniversalVideoMetadata in a map. Only used for quick debugging
  void printAllAttributes() {
    print(convertToMap());
  }
}

/// To make working with search results from different websites easier, every plugin must convert their results to this format
class UniversalSearchResult {
  // required values, with no defaults preset
  /// this id is later used to retrieve video metadata by the videoplayer
  final String videoID;
  final String title;
  final PluginBase? provider;

  // NetworkImage wants Strings instead of Uri
  late String thumbnail;
  late Uri videoPreview;
  late Duration durationInSeconds;
  late int viewsTotal;
  late int ratingsPositivePercent;
  late int maxQuality;
  late bool virtualReality;
  late String author;

  UniversalSearchResult({
    required this.videoID,
    required this.title,
    required this.provider,
    String? author,
    String? thumbnail,
    Uri? videoPreview,
    Duration? durationInSeconds,
    int? viewsTotal,
    int? ratingsPositivePercent,

    /// Use - for lower than, e.g. -720 -> lower than 720p
    int? maxQuality,
    bool? virtualReality,
  })  : author = author ?? "",
        thumbnail = thumbnail ?? "",
        videoPreview = videoPreview ?? Uri.parse(""),
        durationInSeconds = durationInSeconds ?? const Duration(seconds: -1),
        viewsTotal = viewsTotal ?? -1,
        ratingsPositivePercent = ratingsPositivePercent ?? -1,
        maxQuality = maxQuality ?? -1,
        virtualReality = virtualReality ?? false;

  UniversalSearchResult.error()
      : title = "error",
        videoID = "error",
        provider = null;

  /// Returns the entire UniversalVideoMetadata in a map. Only used for testing
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "title": title,
      "author": author,
      "provider": provider,
      "thumbnail": thumbnail,
      "videoPreview": videoPreview,
      "durationInSeconds": durationInSeconds,
      "viewsTotal": viewsTotal,
      "ratingsPositivePercent": ratingsPositivePercent,
      "VideoResolution": maxQuality,
      "virtualReality": virtualReality,
    };
  }

  /// Return the entire  UniversalVideoMetadata in a map. Only used for quick debugging
  void printAllAttributes() {
    print(convertToMap());
  }
}

class UniversalVideoMetadata {
  /// Use the resolution as the key (140, 240, 480, 720, 1080, 1440, 2160)
  final String videoID;
  final Map<int, Uri> m3u8Uris;
  final String title;
  final PluginBase? provider;

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
  late bool virtualReality;
  late Map<Duration, String> chapters;

  UniversalVideoMetadata({
    required this.videoID,
    required this.m3u8Uris,
    required this.title,
    required this.provider,
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
    bool? virtualReality,
    Map<Duration, String>? chapters,
  })  : author = author ?? "",
        authorID = authorID ?? "",
        actors = actors ?? [],
        description = description ?? "",
        viewsTotal = viewsTotal ?? -1,
        tags = tags ?? [],
        categories = categories ?? [],
        uploadDate = uploadDate ?? DateTime.utc(1970, 1, 1),
        ratingsPositiveTotal = ratingsPositiveTotal ?? -1,
        ratingsNegativeTotal = ratingsNegativeTotal ?? -1,
        ratingsTotal = ratingsTotal ?? -1,
        virtualReality = virtualReality ?? false,
        chapters = chapters ?? {};

  UniversalVideoMetadata.error()
      : videoID = "error",
        m3u8Uris = {0: Uri.parse("")},
        title = "error",
        provider = null;

  /// Returns the entire UniversalVideoMetadata in a map. Only used for testing
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "m3u8Uris": m3u8Uris,
      "title": title,
      "provider": provider,
      "author": author,
      "authorID": authorID,
      "actors": actors,
      "description": description,
      "viewsTotal": viewsTotal,
      "tags": tags,
      "categories": categories,
      "uploadDate": uploadDate,
      "ratingsPositiveTotal": ratingsPositiveTotal,
      "ratingsNegativeTotal": ratingsNegativeTotal,
      "ratingsTotal": ratingsTotal,
      "virtualReality": virtualReality,
      "chapters": chapters
    };
  }

  /// Return the entire  UniversalVideoMetadata in a map. Only used for quick debugging
  void printAllAttributes() {
    print(convertToMap());
  }
}
