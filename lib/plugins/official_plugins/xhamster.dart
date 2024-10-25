import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';

import '/backend/plugin_interface.dart';
import '/backend/universal_formats.dart';
import '/main.dart';
import 'official_plugin_base.dart';

class XHamsterPlugin extends PluginBase implements PluginInterface {
  @override
  bool isOfficialPlugin = true;
  @override
  String codeName = "xhamster-official";
  @override
  String prettyName = "xHamster.com";
  @override
  Uri iconUrl = Uri.parse("https://xhamster.com/favicon.ico");
  @override
  String providerUrl = "https://xhamster.com";
  @override
  String videoEndpoint = "https://xhamster.com/videos/";
  @override
  String searchEndpoint = "https://xhamster.com/search/";
  @override
  int initialHomePage = 1;
  @override
  int initialSearchPage = 1;
  @override
  bool providesDownloads = true;
  @override
  bool providesHomepage = true;
  @override
  bool providesResults = true;
  @override
  bool providesSearchSuggestions = true;
  @override
  bool providesVideo = true;

  // The following fields are inherited from PluginInterface, but not needed due to this class not actually being an interface
  @override
  Uri? updateUrl;
  @override
  double version = 1.0;

  @override
  Future<List<UniversalSearchResult>> getHomePage(int page) async {
    Document resultHtml = await requestHtml("$providerUrl/$page");
    if (resultHtml.outerHtml == "<html><head></head><body></body></html>") {
      logger.w("Received empty xhamster homepage html");
      return [];
    }
    return parseVideoPage(resultHtml);
  }

  @override
  Future<List<UniversalSearchResult>> getSearchResults(
      UniversalSearchRequest request, int page) async {
    String encodedSearchString = Uri.encodeComponent(request.searchString);
    Document resultHtml =
        await requestHtml("$searchEndpoint$encodedSearchString?page=$page");
    return parseVideoPage(resultHtml);
  }

  Future<List<UniversalSearchResult>> parseVideoPage(
      Document resultHtml) async {
    List<Element>? resultsList = resultHtml
        .querySelector('div[data-block="trending"]')
        ?.querySelector(".thumb-list")
        ?.querySelectorAll('div')
        .toList();

    // The homepage has "mono" as the data-block
    if (resultHtml.querySelector('div[data-block="trending"]') == null) {
      resultsList = resultHtml
          .querySelector('div[data-block="mono"]')
          ?.querySelector(".thumb-list")
          ?.querySelectorAll('div')
          .toList();
    }

    // convert the divs into UniversalSearchResults
    if (resultsList == null) {
      logger.w("No results found");
      return [];
    }
    List<UniversalSearchResult> results = [];
    for (Element resultDiv in resultsList) {
      try {
        if (resultDiv.attributes['class'] == null) {
          continue;
        }
        // Only select the thumbnail divs
        if (resultDiv.attributes['class']!
            .trim()
            .startsWith("thumb-list__item video-thumb")) {
          // each result has 2 sub-divs
          List<Element>? subElements = resultDiv.children;

          Element? uploaderElement = subElements[1]
              .querySelector('div[class="video-thumb-uploader"]')
              ?.children[0];
          String? author;
          if (uploaderElement != null) {
            // Amateur videos don't have an uploader on the results page
            if (uploaderElement.children.length == 1 &&
                uploaderElement.children[0].className == "video-thumb-views") {
              author = "Unknown amateur author";
            } else {
              author = uploaderElement
                  .querySelector('a[class="video-uploader__name"]')
                  ?.text
                  .trim();
            }
          }

          String? thumbnail =
              subElements[0].querySelector('img')?.attributes['src'];
          String? videoPreview = subElements[0].attributes['data-previewvideo'];
          String? iD = subElements[0].attributes['href']?.split("/").last;
          String? title =
              subElements[1].querySelector('a')?.attributes['title'];
          // convert time string into int list
          List<int> durationList = subElements[0]
              .querySelector('div[class="thumb-image-container__duration"]')!
              .text
              .trim()
              .split(":")
              .map((e) => int.parse(e))
              .toList();

          Duration? duration;
          if (durationList.length == 2) {
            duration =
                Duration(seconds: durationList[0] * 60 + durationList[1]);
            // if there is an hour in the duration
          } else if (durationList.length == 3) {
            duration = Duration(
                seconds: durationList[0] * 3600 +
                    durationList[1] * 60 +
                    durationList[2]);
          }

          // determine video resolution
          int? resolution;
          bool virtualReality = false;
          if (subElements[0].querySelector('i[class^="xh-icon"]') != null) {
            switch (subElements[0]
                .querySelector('i[class^="xh-icon"]')!
                .attributes['class']!
                .split(" ")[1]) {
              case "beta-thumb-hd":
                resolution = 720;
              // TODO: Maybe somehow determine 1080p support?
              case "beta-thumb-uhd":
                resolution = 2160;
              case "beta-thumb-vr":
                virtualReality = true;
            }
          }

          // determine video views
          int? views;
          String? viewsString = subElements[1]
              .querySelector("div[class='video-thumb-views']")
              ?.text
              .trim()
              .split(" views")[0];

          // just added means 0, means skip the whole part coz views is already 0
          if (viewsString == "just added") {
            views = 0;
          } else if (viewsString != null) {
            views = 0;
            if (viewsString.endsWith("K")) {
              if (viewsString.contains(".")) {
                views = int.parse(viewsString.split(".")[1][0]) * 100;
                // this is so that the normal step still works
                // ignore: prefer_interpolation_to_compose_strings
                viewsString = viewsString.split(".")[0] + " ";
              }
              views +=
                  int.parse(viewsString.substring(0, viewsString.length - 1)) *
                      1000;
            } else if (viewsString.endsWith("M")) {
              if (viewsString.contains(".")) {
                views = int.parse(viewsString.split(".")[1][0]) * 100000;
                // this is so that the normal step still works
                // ignore: prefer_interpolation_to_compose_strings
                viewsString = viewsString.split(".")[0] + " ";
              }
              views +=
                  int.parse(viewsString.substring(0, viewsString.length - 1)) *
                      1000000;
            } else {
              views = int.tryParse(viewsString);
            }
          }

          UniversalSearchResult uniResult = UniversalSearchResult(
            videoID: iD ?? "-",
            title: title ?? "-",
            plugin: this,
            thumbnail: thumbnail,
            videoPreview: videoPreview != null ? Uri.parse(videoPreview) : null,
            duration: duration,
            viewsTotal: views,
            // TODO: Find a way to determine ratings (dont seem to be in the html)
            ratingsPositivePercent: null,
            maxQuality: resolution,
            virtualReality: virtualReality,
            author: author,
            // Set to false if null or if the author is "Unknown amateur author"
            verifiedAuthor: author != null && author != "Unknown amateur author",
          );

          // print warnings if some data is missing
          uniResult.printNullKeys(codeName, [
            "thumbnailBinary",
            "lastWatched",
            "firstWatched",
            "ratingsPositivePercent"
          ]);

          results.add(uniResult);
        }
      } catch (e) {
        displayError("Failed to scrape video result: $e");
      }
    }

    return results;
  }

  @override
  Future<UniversalVideoMetadata> getVideoMetadata(String videoId) async {
    Document rawHtml = await requestHtml(videoEndpoint + videoId);

    String jscript = rawHtml.querySelector('#initials-script')!.text;

    // TODO: Maybe check if the m3u8 is a master m3u8
    var videoM3u8 = rawHtml.querySelector(
        'link[rel="preload"][href*=".m3u8"][as="fetch"][crossorigin]');
    var videoTitle =
        rawHtml.querySelector('.with-player-container > h1:nth-child(1)');

    // ratings
    List<String>? ratingRaw =
        rawHtml.querySelector(".rb-new__info")?.text.split(" / ");
    int? ratingsPositive;
    int? ratingsNegative;
    int? ratingsTotal;
    if (ratingRaw != null) {
      ratingsPositive = int.tryParse(ratingRaw[0].replaceAll(",", ""));
      ratingsNegative = int.tryParse(ratingRaw[1].replaceAll(",", ""));
      if (ratingsPositive != null && ratingsNegative != null) {
        ratingsTotal = ratingsPositive + ratingsNegative;
      }
    }

    // Inside the script element, find the views
    String viewsString = jscript.split('"views":').last;
    int? viewsTotal =
        int.tryParse(viewsString.substring(0, viewsString.indexOf(',')));

    // author
    Element? authorRaw = rawHtml.querySelector(".video-tag--subscription");

    // Assume the account doesn't exist anymore
    String? authorString;
    String? authorId;
    if (authorRaw != null) {
      // Most authors have a profile picture. However, those that do not, get a
      // Letter instead of their profile picture. This letter then gets caught
      // when the author name is extracted. The letter is an element inside the
      // main author element
      // => if it exists, remove it
      authorRaw.querySelector(".xh-avatar")?.remove();
      authorString = authorRaw.text.trim();
      authorId = authorRaw.attributes["href"]!.substring(30);
    }

    // actors
    // find the video tags container
    Element rawContainer = rawHtml
        .querySelector("#video-tags-list-container")!
        .children[0]
        .children[0];
    // First element is always the author -> remove it
    rawContainer.children.removeAt(0);
    // categories and actors are in the same list -> sort into two lists
    List<String>? categories = [];
    List<String>? actors = [];
    for (Element element in rawContainer.children) {
      if (element.children[0].attributes["href"] != null) {
        if (element.children[0].attributes["href"]!
            .startsWith("https://xhamster.com/pornstars/")) {
          actors.add(element.children[0].text.trim());
        } else if (element.children[0].attributes["href"]!
            .startsWith("https://xhamster.com/categories/")) {
          categories.add(element.children[0].text.trim());
        }
      }
    }
    if (categories.isEmpty) {
      categories = null;
    }
    if (actors.isEmpty) {
      actors = null;
    }

    // Use the tooltip as video upload date
    DateTime? date;
    String? dateString = rawHtml
        .querySelector(
            'div[class="entity-info-container__date tooltip-nocache"]')
        ?.attributes["data-tooltip"]!;
    // 2022-05-06 12:33:41 UTC
    if (dateString != null) {
      // Convert to a format that DateTime can read
      // Convert to 20120227T132700 format
      dateString = dateString
          .replaceAll("-", "")
          .replaceFirst(" ", "T")
          .replaceAll(":", "")
          .replaceAll(" UTC", "");
      // catch any errors
      try {
        date = DateTime.parse(dateString);
      } on FormatException {
        logger.w("Couldnt convert date to datetime: $dateString");
      }
    }

    if (videoTitle == null ||
        videoM3u8 == null ||
        videoM3u8.attributes["href"] == null) {
      // TODO: add check for vr
      displayError("Couldnt find m3u8 url");
      throw Exception("Couldnt find m3u8 url");
    } else {
      // convert master m3u8 to list of media m3u8
      Map<int, Uri> m3u8Map =
          await parseM3U8(Uri.parse(videoM3u8.attributes["href"]!));

      UniversalVideoMetadata metadata = UniversalVideoMetadata(
          videoID: videoId,
          m3u8Uris: m3u8Map,
          title: videoTitle.text,
          plugin: this,
          author: authorString,
          authorID: authorId,
          actors: actors,
          description: rawHtml.querySelector(".ab-info > p:nth-child(1)")?.text,
          viewsTotal: viewsTotal,
          tags: null,
          categories: categories,
          uploadDate: date,
          ratingsPositiveTotal: ratingsPositive,
          ratingsNegativeTotal: ratingsNegative,
          ratingsTotal: ratingsTotal,
          virtualReality: false,
          chapters: null,
          rawHtml: rawHtml);

      // print warnings if some data is missing
      metadata.printNullKeys(codeName, ["tags", "chapters"]);

      return metadata;
    }
  }

  @override
  Future<List<String>> getSearchSuggestions(String searchString) async {
    List<String> parsedMap = [];
    var response = await http.get(Uri.parse(
        "https://xhamster.com/api/front/search/suggest?searchValue=$searchString"));
    if (response.statusCode == 200) {
      for (var item in jsonDecode(response.body).cast<Map>()) {
        if (item["type2"] == "category") {
          parsedMap.add(item["plainText"]);
        }
      }
    } else {
      displayError(
          "Error downloading json list: ${response.statusCode} - ${response.reasonPhrase}");
    }
    return parsedMap;
  }

  @override
  bool checkAndLoadFromConfig(String configPath) {
    // As this is an official plugin, it doesn't need to be loaded from a file
    return true;
  }

  @override
  Future<bool> initPlugin() {
    // Currently there is no need to init the xhamster plugin. This might change in the future.
    return Future.value(true);
  }

  @override
  bool runFunctionalityTest() {
    // TODO: Implement proper init test for xhamster plugin
    return true;
  }

  @override
  Future<void> isolateGetProgressThumbnails(SendPort sendPort) async {
    // Receive data from the main isolate
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final message = await receivePort.first as List;
    final rawHtml = message[1] as Document;

    // Get the video javascript
    String jscript = rawHtml.querySelector("#initials-script")!.text;

    // Extract the progressImage url from jscript
    int startIndex = jscript.indexOf('"template":"') + 12;
    int endIndex = jscript.substring(startIndex).indexOf('","');
    String imageUrl = jscript.substring(startIndex, startIndex + endIndex);
    String imageBuildUrl = imageUrl.replaceAll("\\/", "/");
    logger.d(imageBuildUrl);

    // Extract the video duration
    int startIndexDuration = jscript.lastIndexOf('"duration":') + 11;
    int endIndexDuration = jscript.substring(startIndexDuration).indexOf(',"');
    String durationInString = jscript.substring(
        startIndexDuration, startIndexDuration + endIndexDuration);
    logger.d(
        "Trying to parse video length in seconds to an int: $durationInString");
    int duration = int.parse(durationInString);

    // Extract the width of the individual preview image from the baseUrl
    String imageWidthString = imageBuildUrl.split("/").last.split(".")[0];
    // New format has the width only, old format has width x height
    int imageWidth = int.parse(imageWidthString.contains("x")
        ? imageWidthString.split("x").first
        : imageWidthString);

    // Assume old format
    String suffix = "";
    String baseUrl = imageBuildUrl;
    // Old format has 50 preview thumbnails for the entire video
    int samplingFrequency = (duration / 50).floor();
    // only one combined image in old format
    int lastImageIndex = 0;
    bool isOldFormat = true;

    // determine kind of preview images
    logger.d("Checking whether video uses new preview format");
    if (imageBuildUrl.endsWith("%d.webp")) {
      isOldFormat = false;
      suffix = ".${imageBuildUrl.split(".").last}";
      logger.d(suffix);
      baseUrl = imageBuildUrl.split("%d").first;
      logger.d(baseUrl);
      // from limited testing it seems as if the sampling frequency is always 4 in the new format, but have this just in case
      // Although usually the sampling frequency is not 4.0, but rather something like 4.003
      // For some reason xhamster just ignores that and uses a whole number resulting in drift at the end in long videos.
      samplingFrequency =
          int.parse(imageBuildUrl.split("/").last.split(".")[1]);
      logger.d(samplingFrequency);
      // Each combined image contains 50 images
      lastImageIndex = duration ~/ samplingFrequency ~/ 50;
    }
    logger.d("Is old format: $isOldFormat");
    logger.d("Sampling frequency: $samplingFrequency");

    logger.i("Downloading and processing progress images");
    logger.d("lastImageIndex: $lastImageIndex");
    List<List<Uint8List>> allThumbnails =
        List.generate(lastImageIndex + 1, (_) => []);
    List<Future<void>> imageFutures = [];

    for (int i = 0; i <= lastImageIndex; i++) {
      // Create a future for downloading and processing
      imageFutures.add(Future(() async {
        String url = isOldFormat ? baseUrl : "$baseUrl$i$suffix";
        logger.d("Preparing to download $url");
        Uint8List image = await downloadThumbnail(Uri.parse(url));
        logger.d("Cutting image $url into progress images");
        final decodedImage = decodeImage(image)!;
        List<Uint8List> thumbnails = [];
        for (int w = 0; w < decodedImage.width; w += imageWidth) {
          logger.d(
              "X: $w, Y: 0, Width: $imageWidth, Height: ${decodedImage.height}");
          // XHamster has a set amount of thumbnails (usually multiples of 50) for the whole video.
          // every progress image is for samplingFrequency (usually 4) seconds -> store the same image samplingFrequency times
          // To avoid overfilling the ram, create a temporary variable and store it in the list multiple times
          // As Lists contain references to data and not the data itself, this should reduce ram usage
          Uint8List firstThumbnail = Uint8List(0);
          for (int j = 0; j < samplingFrequency; j++) {
            if (j == 0) {
              // Only encode and add the first image once
              firstThumbnail = encodeJpg(copyCrop(decodedImage,
                  x: w, y: 0, width: imageWidth, height: decodedImage.height));
              thumbnails.add(firstThumbnail); // Add the first encoded image
            } else {
              // Reuse the reference to the first thumbnail
              thumbnails.add(firstThumbnail);
            }
          }
        }
        allThumbnails[i] = thumbnails;
        logger.d("Completed processing $url");
      }));
    }
    // Await all futures
    await Future.wait(imageFutures);

    // Combine all results into single, chronological list
    logger.d("Combining all results into single, chronological list");
    List<Uint8List> completedProcessedImages =
        allThumbnails.expand((x) => x).toList();

    // Add 55 seconds more of the last thumbnail
    // This is done as the sampling frequency is floored. 0.99*50 = 49.5, means in theory we could be off by 50 seconds
    Uint8List lastImage = completedProcessedImages.last;
    for (int j = 0; j < 55; j++) {
      completedProcessedImages.add(lastImage);
    }

    logger.i("Completed processing all images");
    logger.d(
        "Total memory consumption apprx: ${completedProcessedImages[0].lengthInBytes * completedProcessedImages.length / 1024 / 1024} mb");
    // return the completed processed images through the separate resultsPort
    logger.d(
        "Sending ${completedProcessedImages.length} progress images to main process");
    message[2].send(completedProcessedImages);
  }
}
