import 'dart:typed_data';

import 'package:html/dom.dart';

import '/utils/global_vars.dart';
import '/utils/plugin_interface.dart';

// shared functions
String convertNumberIntoHumanReadable(int number) {
  if (number < 1000) {
    return number.toString();
    // <100k
  } else if (number < 100000) {
    return "${(number / 1000).toStringAsFixed(1)}K";
    // <1M
  } else if (number < 1000000) {
    return "${(number / 1000).toStringAsFixed(0)}K";
    // <10M
  } else if (number < 10000000) {
    return "${(number / 1000000).toStringAsFixed(1)}M";
    // >10M
  } else {
    return "${(number / 1000000).toStringAsFixed(0)}M";
  }
}

String? getTimeDeltaInHumanReadable(DateTime? pastDate) {
  if (pastDate == null) {
    return null;
  }
  Duration delta = DateTime.now().difference(pastDate);
  if (delta.inSeconds < 60) {
    return "${delta.inSeconds}s";
  } else if (delta.inMinutes < 60) {
    return "${delta.inMinutes}m";
  } else if (delta.inHours < 24) {
    return "${delta.inHours}h";
  } else if (delta.inDays < 30) {
    return "${delta.inDays}d";
  } else if (delta.inDays < 365) {
    return "${delta.inDays ~/ 30}mo";
  } else {
    return "${delta.inDays ~/ 365}y";
  }
}

class UniversalSearchRequest {
  /// Whether this search result is coming from the database search history or not
  late String searchString;
  late String sortingType;
  late String dateRange;
  late int minQuality;
  late int maxQuality;
  late int minDuration;
  late int maxDuration;
  late int minFramesPerSecond;
  late int maxFramesPerSecond;
  late bool virtualReality;
  late List<String> categoriesInclude;
  late List<String> categoriesExclude;
  late List<String> keywordsInclude;
  late List<String> keywordsExclude;
  late bool historySearch;

  // TODO: Add verified, professional and unverified

  // make providing any values optional, but also have defaults set for all of them
  UniversalSearchRequest({
    String? searchString,
    String? sortingType,
    String? dateRange,
    int? minQuality,
    int? maxQuality,
    int? minDuration,
    int? maxDuration,
    int? minFramesPerSecond,
    int? maxFramesPerSecond,
    bool? virtualReality,
    List<String>? categoriesInclude,
    List<String>? categoriesExclude,
    List<String>? keywordsInclude,
    List<String>? keywordsExclude,
    bool? historySearch,
  })  : searchString = searchString ?? "",
        sortingType = sortingType ?? "Relevance",
        dateRange = dateRange ?? "All time",
        minQuality = minQuality ?? 0,
        maxQuality = maxQuality ?? 2160,
        minDuration = minDuration ?? 0,
        maxDuration = maxDuration ?? 3600,
        minFramesPerSecond = minFramesPerSecond ?? 0,
        maxFramesPerSecond = maxFramesPerSecond ?? 60,
        virtualReality = virtualReality ?? false,
        categoriesInclude = categoriesInclude ?? [],
        categoriesExclude = categoriesExclude ?? [],
        keywordsInclude = keywordsInclude ?? [],
        keywordsExclude = keywordsExclude ?? [],
        historySearch = historySearch ?? false;

  /// Returns the entire UniversalSearchRequest in a map. Only used for debugging
  Map<String, dynamic> convertToMap() {
    return {
      "searchString": searchString,
      "sortingType": sortingType,
      "dateRange": dateRange,
      "minQuality": minQuality,
      "maxQuality": maxQuality,
      "minDuration": minDuration,
      "maxDuration": maxDuration,
      "minFramesPerSecond": minFramesPerSecond,
      "maxFramesPerSecond": minFramesPerSecond,
      "virtualReality": virtualReality,
      "categoriesInclude": categoriesInclude,
      "categoriesExclude": categoriesExclude,
      "keywordsInclude": keywordsInclude,
      "keywordsExclude": keywordsExclude,
      "historySearch": historySearch
    };
  }

  /// Return the entire  UniversalSearchRequest in a map. Only used for debugging
  void printAllAttributes() {
    logger.d(convertToMap());
  }
}

/// To make working with search results from different websites easier, every plugin must convert their results to this format
class UniversalVideoPreview {
  /// this id is later used to retrieve video metadata by the videoplayer
  final String videoID;
  final String title;
  final PluginInterface? plugin;

  // NetworkImage wants Strings instead of Uri
  final String? thumbnail;
  final Uint8List thumbnailBinary;
  final Uri? previewVideo;
  final Duration? duration;
  final int? viewsTotal;

  /// int from 0 to 100 representing the percentage of positive ratings
  final int? ratingsPositivePercent;
  final int? maxQuality;
  final bool virtualReality;
  final String? author;
  final bool verifiedAuthor;

  // Only needed for watch history
  final DateTime? lastWatched;
  final DateTime? addedOn;

  UniversalVideoPreview({
    required this.videoID,
    required this.title,
    required this.plugin,
    this.thumbnail,
    Uint8List? thumbnailBinary,
    this.previewVideo,
    this.duration,
    this.viewsTotal,
    this.ratingsPositivePercent,

    /// Use - for lower than, e.g. -720 -> lower than 720p
    this.maxQuality,
    bool? virtualReality,
    this.author,
    bool? verifiedAuthor,

    /// Optional, only needed for watch history
    this.lastWatched,
    this.addedOn,
  })  : verifiedAuthor = verifiedAuthor ?? false,
        virtualReality = virtualReality ?? false,
        thumbnailBinary = thumbnailBinary ?? Uint8List(0);

  /// Returns the entire UniversalVideoPreview in a map. Only used for debugging
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "title": title,
      "plugin": plugin?.codeName,
      "thumbnail": thumbnail,
      "thumbnailBinary": thumbnailBinary,
      "previewVideo": previewVideo,
      "duration": duration?.inSeconds,
      "viewsTotal": viewsTotal,
      "ratingsPositivePercent": ratingsPositivePercent,
      "maxQuality": maxQuality,
      "virtualReality": virtualReality,
      "author": author,
      "verifiedAuthor": verifiedAuthor,
      "lastWatched": lastWatched,
      "addedOn": addedOn
    };
  }

  /// Return the entire  UniversalVideoPreview in a map. Only used for debugging
  void printAllAttributes() {
    Map<String, dynamic> result = convertToMap();
    // convert all dynamics to strings, as logger only accepts strings
    logger.d(result.map((key, value) => MapEntry(key, value.toString())));
  }

  /// Print values that are null, but the plugin didn't expect to be null
  // TODO: Set up automatic/user prompted reporting
  void printNullKeys(String pluginCodeName, List<String> exceptions) {
    Map<String, dynamic> objectAsMap = convertToMap();
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    objectAsMap.forEach((key, value) {
      if (!exceptions.contains(key) && value == null) {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.w(
          "$pluginCodeName: UniversalVideoPreview ($videoID): Failed to scrape keys: $nullKeys");
    }
  }
}

class UniversalVideoMetadata {
  /// Use the resolution as the key (140, 240, 480, 720, 1080, 1440, 2160)
  final String videoID;
  final Map<int, Uri> m3u8Uris;
  final String title;
  final PluginInterface? plugin;

  final String? author;
  final String? authorID;
  final List? actors;
  final String? description;
  final int? viewsTotal;
  final List? tags;
  final List? categories;
  final DateTime? uploadDate;
  final int? ratingsPositiveTotal;
  final int? ratingsNegativeTotal;
  final int? ratingsTotal;
  final bool virtualReality;
  final Map<Duration, String>? chapters;

  /// The getPreviewThumbnails functions might require the html. To avoid redownloading it, it will be directly passed to the function
  final Document rawHtml;

  UniversalVideoMetadata({
    required this.videoID,
    required this.m3u8Uris,
    required this.title,
    required this.plugin,
    this.author,
    this.authorID,
    this.actors,
    this.description,
    this.viewsTotal,
    this.tags,
    this.categories,
    this.uploadDate,
    this.ratingsPositiveTotal,
    this.ratingsNegativeTotal,
    this.ratingsTotal,
    bool? virtualReality,
    this.chapters,
    Document? rawHtml,
  })  : virtualReality = virtualReality ?? false,
        rawHtml = rawHtml ?? Document();

  /// Returns the entire UniversalVideoMetadata in a map.
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "m3u8Uris": m3u8Uris,
      "title": title,
      "plugin": plugin?.codeName,
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
    logger.d(convertToMap());
  }

  /// Print values that are null, but the plugin didn't expect to be null
  // TODO: Set up automatic/user prompted reporting
  void printNullKeys(String pluginCodeName, List<String> exceptions) {
    Map<String, dynamic> objectAsMap = convertToMap();
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    objectAsMap.forEach((key, value) {
      if (!exceptions.contains(key) && value == null) {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.w(
          "$pluginCodeName: UniversalVideoMetadata ($videoID): Failed to scrape keys: $nullKeys");
    }
  }
}

class UniversalComment {
  final String videoID;
  final String author;
  final String commentBody;

  /// Whether the comment was hidden by the platform / creator
  final bool hidden;
  final PluginInterface? plugin;

  final String? authorID;

  /// Unique Identifier for this exact comment. Usually used in conjunction with videoID
  final String? commentID;

  /// Two letter country code
  final String? countryID;

  /// Sexual orientation of the profile
  final String? orientation;

  // NetworkImage wants Strings instead of Uri
  final String? profilePicture;
  final int? ratingsPositiveTotal;
  final int? ratingsNegativeTotal;
  final int? ratingsTotal;
  final DateTime? commentDate;

  // Sometimes the reply comments are scraped/loaded after the main comment
  late List<UniversalComment>? replyComments;

  UniversalComment({
    required this.videoID,
    required this.author,
    required this.commentBody,
    required this.hidden,
    required this.plugin,
    this.authorID,
    this.commentID,
    this.countryID,
    this.orientation,
    this.profilePicture,
    this.ratingsPositiveTotal,
    this.ratingsNegativeTotal,
    this.ratingsTotal,
    this.commentDate,
    this.replyComments,
  });

  /// Returns the entire UniversalVideoMetadata in a map.
  Map<String, dynamic> convertToMap() {
    return {
      "videoID": videoID,
      "author": author,
      "commentBody": commentBody,
      "plugin": plugin?.codeName ?? "no plugin?",
      "authorID": authorID,
      "commentID": commentID,
      "countryID": countryID,
      "orientation": orientation,
      "profilePicture": profilePicture,
      "ratingsPositiveTotal": ratingsPositiveTotal,
      "ratingsNegativeTotal": ratingsNegativeTotal,
      "ratingsTotal": ratingsTotal,
      "commentDate": commentDate
    };
  }

  /// Return the entire UniversalComment in a map. Only used for quick debugging
  void printAllAttributes() {
    logger.d(convertToMap());
  }

  /// Print values that are null, but the plugin didn't expect to be null
  // TODO: Set up automatic/user prompted reporting
  void printNullKeys(String pluginCodeName, List<String> exceptions) {
    Map<String, dynamic> objectAsMap = convertToMap();
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    objectAsMap.forEach((key, value) {
      if (!exceptions.contains(key) && value == null) {
        nullKeys.add(key);
      }
    });
    logger.d(
        "$pluginCodeName: UniversalComment ($commentID): Failed to scrape keys: $nullKeys");
  }
}
