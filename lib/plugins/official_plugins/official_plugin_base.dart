import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

import '/main.dart';

/// This class contains internal functions / pre-implemented functions for official plugins
abstract class PluginBase {
  /// The pluginInterface runs all functions as isolates due to the nature of how third-party plugins are implemented
  /// However, most functions are not that performance heavy and can be run in the main isolate, except for getProgressThumbnails
  /// This function is called by the main isolate and overrides the pluginInterface one in official plugins
  /// DO NOT OVERRIDE THIS FUNCTION IN THE OFFICIAL PLUGINS
  Future<List<Uint8List>> getProgressThumbnails(
      String videoID, Document rawHtml) async {
    // spawn the isolate
    final receivePort = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    final isolate =
        await Isolate.spawn(isolateGetProgressThumbnails, receivePort.sendPort);
    final SendPort sendPort = await receivePort.first as SendPort;

    // pass the arguments
    final resultsPort = ReceivePort(); // for receiving the results
    logger.d("Sending arguments to isolate process");
    sendPort.send([rootToken, resultsPort.sendPort, videoID, rawHtml]);

    // Wait for the results
    final List<Uint8List> thumbnails =
        await resultsPort.first as List<Uint8List>;
    logger.d("Received ${thumbnails.length} thumbnails from isolate process");
    // Cleanup
    receivePort.close();
    isolate.kill(priority: Isolate.immediate);
    return thumbnails;
  }

  /// This is the actual function for getting thumbnails that is specific to each official plugin
  Future<void> isolateGetProgressThumbnails(SendPort sendPort);

  Future<Uint8List> downloadThumbnail(Uri uri) async {
    try {
      var response = await http.get(uri);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        logger.e(
            "Error downloading preview: ${response.statusCode} - ${response.reasonPhrase}");
        return Uint8List(0);
      }
    } catch (e, stacktrace) {
      logger.e("Error downloading preview: $e\n$stacktrace");
      return Uint8List(0);
    }
  }

  /// Parse a master m3u8 into media m3u8s
  Future<Map<int, Uri>> parseM3U8(Uri playListUri) async {
    Map<int, Uri> playListMap = {};
    // download and convert the m3u8 into a string
    var response = await http.get(playListUri);
    if (response.statusCode == 200) {
      String contentString = response.body;
      HlsMasterPlaylist? playList = (await HlsPlaylistParser.create()
          .parseString(playListUri, contentString)) as HlsMasterPlaylist?;

      // verify the playList is not empty
      if (playList != null) {
        for (var variant in playList.variants) {
          if (variant.format.height != null) {
            playListMap[variant.format.height!] = variant.url;
          } else {
            logger.e("Error parsing m3u8: $playListUri");
          }
        }
      } else {
        logger.e("M3U8 is empty: $playListUri");
      }
    } else {
      logger.e(
          "Error downloading m3u8 master file: ${response.statusCode} - ${response.reasonPhrase}");
    }
    return playListMap;
  }
}
