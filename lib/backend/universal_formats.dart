import 'dart:typed_data';

import 'package:hedon_viewer/backend/plugin_base.dart';

class UniversalSearchRequest {
  late String searchString;
  late int minimalFramesPerSecond;
  late int minimalQuality;
  late int minimalDuration;
  late int maximalDuration;
  late List<String> categories;
  late String sortingType;
  late String timeframe;
  late bool virtualReality;

  // make providing any values optional, even searchString
  UniversalSearchRequest({
    String? searchString,
    int? minimalFramesPerSecond,
    int? minimalQuality,
    int? minimalDuration,
    int? maximalDuration,
    List<String>? categories,
    String? sortingType,
    String? timeframe,
    bool? virtualReality,
  })  : searchString = searchString ?? "",
        minimalFramesPerSecond = minimalFramesPerSecond ?? -1,
        minimalQuality = minimalQuality ?? -1,
        minimalDuration = minimalDuration ?? 0,
        maximalDuration = maximalDuration ?? -1,
        categories = categories ?? [],
        sortingType = sortingType ?? "",
        timeframe = timeframe ?? "",
        virtualReality = virtualReality ?? false;

  /// Returns the entire UniversalSearchRequest in a map. Only used for debugging
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

  /// Return the entire  UniversalSearchRequest in a map. Only used for debugging
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
  late Uint8List thumbnailBinary;
  late Uri videoPreview;
  late Duration duration;
  late int viewsTotal;
  late int ratingsPositivePercent;
  late int maxQuality;
  late bool virtualReality;
  late String author;
  late bool verifiedAuthor;

  // Only needed for watch history
  late DateTime lastWatched;
  late DateTime firstWatched;

  UniversalSearchResult({
    required this.videoID,
    required this.title,
    required this.provider,
    String? author,
    bool? verifiedAuthor,
    String? thumbnail,
    Uint8List? thumbnailBinary,
    Uri? videoPreview,
    Duration? duration,
    int? viewsTotal,
    int? ratingsPositivePercent,

    /// Use - for lower than, e.g. -720 -> lower than 720p
    int? maxQuality,
    bool? virtualReality,

    /// Optional, only needed for watch history
    DateTime? lastWatched,
    DateTime? firstWatched,
  })  : author = author ?? "",
        verifiedAuthor = verifiedAuthor ?? false,
        thumbnail = thumbnail ?? "",
        thumbnailBinary = thumbnailBinary ?? Uint8List(0),
        videoPreview = videoPreview ?? Uri.parse(""),
        duration = duration ?? const Duration(seconds: -1),
        viewsTotal = viewsTotal ?? -1,
        ratingsPositivePercent = ratingsPositivePercent ?? -1,
        maxQuality = maxQuality ?? -1,
        virtualReality = virtualReality ?? false,
        lastWatched = lastWatched ?? DateTime.utc(1970, 1, 1),
        firstWatched = firstWatched ?? DateTime.utc(1970, 1, 1);

  UniversalSearchResult.error()
      : title = "error",
        videoID = "error",
        provider = null;

  /// Returns the entire UniversalSearchResult in a map. Only used for debugging
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "title": title,
      "author": author,
      "verifiedAuthor": verifiedAuthor,
      "provider": provider?.pluginName ?? "no provider?",
      "thumbnail": thumbnail,
      "videoPreview": videoPreview,
      "duration in seconds": duration.inSeconds,
      "viewsTotal": viewsTotal,
      "ratingsPositivePercent": ratingsPositivePercent,
      "VideoResolution": maxQuality,
      "virtualReality": virtualReality,
    };
  }

  /// Return the entire  UniversalSearchResult in a map. Only used for debugging
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

  /// Returns the entire UniversalVideoMetadata in a map. Only used for debugging
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "m3u8Uris": m3u8Uris,
      "title": title,
      "provider": provider?.pluginName ?? "no provider?",
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
