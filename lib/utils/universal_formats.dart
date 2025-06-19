import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '/utils/global_vars.dart';
import '/utils/plugin_interface.dart';

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

  Map<String, dynamic> toMap() {
    return {
      "searchString": searchString,
      "sortingType": sortingType,
      "dateRange": dateRange,
      "minQuality": minQuality,
      "maxQuality": maxQuality,
      "minDuration": minDuration,
      "maxDuration": maxDuration,
      "minFramesPerSecond": minFramesPerSecond,
      "maxFramesPerSecond": maxFramesPerSecond,
      "virtualReality": virtualReality,
      "categoriesInclude": categoriesInclude,
      "categoriesExclude": categoriesExclude,
      "keywordsInclude": keywordsInclude,
      "keywordsExclude": keywordsExclude,
      "historySearch": historySearch
    };
  }
}

/// To make working with search results from different websites easier, every plugin must convert their results to this format
class UniversalVideoPreview {
  /// this id is later used to retrieve video metadata by the videoplayer
  final String iD;
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
  final String? authorID;
  final bool verifiedAuthor;

  // Only needed for watch history
  final DateTime? lastWatched;
  final DateTime? addedOn;

  /// If not null, indicates issue with the scrape
  /// If starts with "Error", gets displayed differently in scraping_report
  /// The message itself is shown to the user in the scraping_report and is sent in bug reports
  String? scrapeFailMessage;

  /// Empty constructor for skeleton
  UniversalVideoPreview.skeleton()
      : this(
            iD: "",
            plugin: null,
            thumbnail: "mockThumbnail",
            title: BoneMock.paragraph,
            viewsTotal: 100,
            maxQuality: 100,
            ratingsPositivePercent: 10,
            author: BoneMock.name);

  UniversalVideoPreview({
    required this.iD,
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

    /// AuthorID that can be passed to getAuthorPage. For most websites its
    /// the same as the human-readable author
    this.authorID,
    bool? verifiedAuthor,

    /// Optional, only needed for watch history
    this.lastWatched,
    this.addedOn,
    this.scrapeFailMessage,
  })  : verifiedAuthor = verifiedAuthor ?? false,
        virtualReality = virtualReality ?? false,
        thumbnailBinary = thumbnailBinary ?? Uint8List(0);

  /// Safe to wrap with in jsonEncode
  Map<String, dynamic> toMap() {
    return {
      "iD": iD,
      "title": title,
      "plugin": plugin?.codeName,
      "thumbnail": thumbnail,
      "thumbnailBinary": thumbnailBinary.toString(),
      "previewVideo": previewVideo?.toString(),
      "durationInSeconds": duration?.inSeconds,
      "viewsTotal": viewsTotal,
      "ratingsPositivePercent": ratingsPositivePercent,
      "maxQuality": maxQuality,
      "virtualReality": virtualReality,
      "author": author,
      "authorID": authorID,
      "verifiedAuthor": verifiedAuthor,
      "lastWatched": lastWatched?.toString(),
      "addedOn": addedOn?.toString(),
      "scrapeFailMessage": scrapeFailMessage
    };
  }

  /// Print values that are null, but the plugin didn't expect to be null
  /// Also returns a bool whether the data is valid
  bool verifyScrapedData(String pluginCodeName, List<String> exceptions) {
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    toMap().forEach((key, value) {
      if (!exceptions.contains(key) &&
          value == null &&
          key != "scrapeFailMessage") {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.w(
          "$pluginCodeName: UniversalVideoPreview ($iD): Failed to scrape keys: $nullKeys");
      scrapeFailMessage = "Failed to scrape keys: $nullKeys";
      return false;
    }
    return true;
  }
}

class UniversalVideoMetadata {
  final String iD;
  final Map<int, Uri> m3u8Uris;
  final String title;
  final PluginInterface? plugin;

  /// The UniversalVideoPreview of this video metadata
  /// Converting a uvm to a uvp is impossible but a uvp is required for the
  /// favorite-button to work on the video_screen
  final UniversalVideoPreview universalVideoPreview;

  final String authorID;
  final String? authorName;
  final int? authorSubscriberCount;
  final String? authorAvatar;
  final List<String>? actors;
  final String? description;
  final int? viewsTotal;
  final List<String>? tags;
  final List<String>? categories;
  final DateTime? uploadDate;
  final int? ratingsPositiveTotal;
  final int? ratingsNegativeTotal;
  final int? ratingsTotal;
  final bool virtualReality;
  final Map<Duration, String>? chapters;

  /// The getPreviewThumbnails functions might require the html. To avoid redownloading it, it will be directly passed to the function
  final Document rawHtml;

  /// If not null, indicates issue with the scrape
  /// If starts with "Error", gets displayed differently in scraping_report
  /// The message itself is shown to the user in the scraping_report and is sent in bug reports
  String? scrapeFailMessage;

  /// Empty constructor for skeleton
  UniversalVideoMetadata.skeleton()
      : this(
            iD: 'none',
            m3u8Uris: {},
            title: List<String>.filled(10, 'title').join(),
            // long string
            plugin: null,
            universalVideoPreview: UniversalVideoPreview.skeleton(),
            authorID: 'none',
            authorName: BoneMock.name,
            authorAvatar: "mockAvatar");

  UniversalVideoMetadata({
    required this.iD,
    required this.m3u8Uris,
    required this.title,
    required this.plugin,
    required this.universalVideoPreview,
    required this.authorID,
    this.authorName,
    this.authorSubscriberCount,
    this.authorAvatar,
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
    this.scrapeFailMessage,
  })  : virtualReality = virtualReality ?? false,
        rawHtml = rawHtml ?? Document();

  /// Safe to wrap with in jsonEncode
  Map<String, dynamic> toMap() {
    return {
      "iD": iD,
      "m3u8Uris": m3u8Uris.toString(),
      "title": title,
      "plugin": plugin?.codeName,
      "universalVideoPreview": universalVideoPreview.toMap(),
      "authorID": authorID,
      "authorName": authorName,
      "authorSubscriberCount": authorSubscriberCount,
      "authorAvatar": authorAvatar,
      "actors": actors,
      "description": description,
      "viewsTotal": viewsTotal,
      "tags": tags,
      "categories": categories,
      "uploadDate": uploadDate?.toString(),
      "ratingsPositiveTotal": ratingsPositiveTotal,
      "ratingsNegativeTotal": ratingsNegativeTotal,
      "ratingsTotal": ratingsTotal,
      "virtualReality": virtualReality,
      "chapters": chapters?.toString(),
      "rawHtml": "Not shown due to length",
      "scrapeFailMessage": scrapeFailMessage
    };
  }

  /// Print values that are null, but the plugin didn't expect to be null
  /// Also returns a bool whether the data is valid
  // TODO: Set up automatic/user prompted reporting
  bool verifyScrapedData(String pluginCodeName, List<String> exceptions) {
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    toMap().forEach((key, value) {
      if (!exceptions.contains(key) &&
          value == null &&
          key != "scrapeFailMessage") {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.w(
          "$pluginCodeName: UniversalVideoMetadata ($iD): Failed to scrape keys: $nullKeys");
      scrapeFailMessage = "Failed to scrape keys: $nullKeys";
      return false;
    }
    return true;
  }
}

class UniversalAuthorPage {
  /// The author ID
  final String iD;
  final String name;
  final PluginInterface? plugin;

  // NetworkImage wants Strings instead of Uri
  final String? thumbnail;
  final String? banner;
  final List<String>? aliases;
  final String? description;
  final Map<String, String>? advancedDescription;
  final Map<String, Uri>? externalLinks;
  final int? viewsTotal;
  final int? videosTotal;
  final int? subscribers;
  final int? rank;

  // Only needed for watch history
  final DateTime? lastViewed;
  final DateTime? addedOn;

  /// If not null, indicates issue with the scrape
  /// If starts with "Error", gets displayed differently in scraping_report
  /// The message itself is shown to the user in the scraping_report and is sent in bug reports
  String? scrapeFailMessage;

  /// Empty constructor for skeleton
  UniversalAuthorPage.skeleton()
      : this(
            iD: "",
            name: BoneMock.name,
            plugin: null,
            thumbnail: "mockThumbnail",
            banner: "mockBanner",
            externalLinks: {"": Uri.parse("")},
            viewsTotal: 100,
            videosTotal: 100,
            subscribers: 100,
            rank: 100);

  UniversalAuthorPage({
    required this.iD,
    required this.name,
    required this.plugin,
    this.thumbnail,
    this.banner,
    this.aliases,
    this.description,
    this.advancedDescription,
    this.externalLinks,
    this.viewsTotal,
    this.videosTotal,
    this.subscribers,
    this.rank,

    /// Optional, only needed for watch history
    this.lastViewed,
    this.addedOn,
    this.scrapeFailMessage,
  });

  /// Safe to wrap with in jsonEncode
  Map<String, dynamic> toMap() {
    return {
      "iD": iD,
      "name": name,
      "plugin": plugin?.codeName,
      "thumbnail": thumbnail,
      "banner": banner,
      "aliases": aliases.toString(),
      "description": description,
      "advancedDescription": advancedDescription.toString(),
      "externalLinks": externalLinks.toString(),
      "viewsTotal": viewsTotal,
      "videosTotal": videosTotal,
      "subscribers": subscribers,
      "rank": rank,
      "lastViewed": lastViewed?.toString(),
      "addedOn": addedOn?.toString(),
      "scrapeFailMessage": scrapeFailMessage
    };
  }

  /// Print values that are null, but the plugin didn't expect to be null
  /// Also returns a bool whether the data is valid
  bool verifyScrapedData(String pluginCodeName, List<String> exceptions) {
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    toMap().forEach((key, value) {
      if (!exceptions.contains(key) &&
          value == null &&
          key != "scrapeFailMessage") {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.w(
          "$pluginCodeName: UniversalAuthorPage ($iD): Failed to scrape keys: $nullKeys");
      scrapeFailMessage = "Failed to scrape keys: $nullKeys";
      return false;
    }
    return true;
  }
}

class UniversalComment {
  /// Unique Identifier for this exact comment. Use in conjunction with videoID
  final String iD;
  final String videoID;
  final String author;
  final String commentBody;

  /// Whether the comment was hidden by the platform / creator
  final bool hidden;
  final PluginInterface? plugin;

  final String? authorID;

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

  /// If not null, indicates issue with the scrape
  /// If starts with "Error", gets displayed differently in scraping_report
  /// The message itself is shown to the user in the scraping_report and is sent in bug reports
  String? scrapeFailMessage;

  /// Empty constructor for skeleton
  UniversalComment.skeleton()
      : this(
            iD: "",
            videoID: "",
            author: "author",
            commentBody: List<String>.filled(5, "comment").join(),
            hidden: false,
            plugin: null);

  UniversalComment({
    required this.iD,
    required this.videoID,
    required this.author,
    required this.commentBody,
    required this.hidden,
    required this.plugin,
    this.authorID,
    this.countryID,
    this.orientation,
    this.profilePicture,
    this.ratingsPositiveTotal,
    this.ratingsNegativeTotal,
    this.ratingsTotal,
    this.commentDate,
    this.replyComments,
    this.scrapeFailMessage,
  });

  /// Safe to wrap with in jsonEncode
  Map<String, dynamic> toMap() {
    return {
      "iD": iD,
      "videoID": videoID,
      "author": author,
      "commentBody": commentBody,
      "hidden": hidden,
      "plugin": plugin?.codeName,
      "authorID": authorID,
      "countryID": countryID,
      "orientation": orientation,
      "profilePicture": profilePicture,
      "ratingsPositiveTotal": ratingsPositiveTotal,
      "ratingsNegativeTotal": ratingsNegativeTotal,
      "ratingsTotal": ratingsTotal,
      "commentDate": commentDate?.toString(),
      "replyComments":
          replyComments?.map((comment) => comment.toMap()).toList().toString(),
      "scrapeFailMessage": scrapeFailMessage,
    };
  }

  void printAllAttributes() {
    logger.d(toMap());
  }

  /// Print values that are null, but the plugin didn't expect to be null
  /// Also returns a bool whether the data is valid
  // TODO: Set up automatic/user prompted reporting
  bool verifyScrapedData(String pluginCodeName, List<String> exceptions) {
    List<String> nullKeys = [];
    // Check whether key is not in exception list and whether value is null
    toMap().forEach((key, value) {
      if (!exceptions.contains(key) &&
          value == null &&
          key != "scrapeFailMessage") {
        nullKeys.add(key);
      }
    });
    if (nullKeys.isNotEmpty) {
      logger.d(
          "$pluginCodeName: UniversalComment ($iD): Failed to scrape keys: $nullKeys");
      scrapeFailMessage = "Failed to scrape keys: $nullKeys";
      return false;
    }
    return true;
  }
}
