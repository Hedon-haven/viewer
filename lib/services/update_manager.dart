import 'dart:convert';
import 'dart:io';

import 'package:apk_installer/apk_installer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:system_info2/system_info2.dart';

import '/utils/global_vars.dart';

class UpdateManager extends ChangeNotifier {
  String? latestTag;
  String? latestChangeLog;
  double downloadProgress = 0.0;

  Future<List<String?>> checkForUpdate() async {
    // Check if using linux
    if (Platform.isLinux) {
      logger.w("Linux updates are handled via flatpak!");
      return [latestTag, latestChangeLog];
    }

    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      // Don't throw exception, to avoid popping up in offline mode
      logger.w("No internet connection, canceling update check");
      return [latestTag, latestChangeLog];
    }

    // Get current version
    String localVersion = packageInfo.version;
    // get remote version
    final responseVersion =
        await client.get(Uri.parse("https://changelog.hedon-haven.top/latest"));
    if (responseVersion.statusCode != 200) {
      throw Exception("Couldn't fetch latest version");
    }
    latestTag = responseVersion.body;
    // Get latest changelog
    final responseChangelog = await client
        .get(Uri.parse("https://changelog.hedon-haven.top/$latestTag"));
    if (responseChangelog.statusCode != 200) {
      throw Exception("Couldn't fetch $latestTag changelog");
    }
    latestChangeLog = responseChangelog.body.trim();
    List<int> localVersionList = [];
    List<int> remoteVersionList = [];

    try {
      // convert to lists of integers
      logger.d("Attempting to convert versions to list of integers");
      logger.d("Current version: $localVersion");
      // Print without leading "v"
      logger.d("Remote version: ${latestTag!.substring(1)}");
      localVersionList = localVersion.split('.').map(int.parse).toList();
      // remove leading 'v'
      remoteVersionList =
          latestTag!.substring(1).split('.').map(int.parse).toList();
    } on FormatException {
      throw Exception("Invalid remote version format");
    }

    // make sure both lists are exactly 3 elements long
    if (localVersionList.length != 3 || remoteVersionList.length != 3) {
      throw Exception("Remote version format too long");
    }

    // compare versions
    // if any part of the version is lower, update is available
    if (localVersionList[0] < remoteVersionList[0] ||
        localVersionList[1] < remoteVersionList[1] ||
        localVersionList[2] < remoteVersionList[2]) {
      logger.i("Local version is lower, update available");
    } else {
      logger.i("Local version matches remote version, no update available");
      return [null, null];
    }
    return [latestTag, latestChangeLog];
  }

  Future<void> downloadAndInstallUpdate(String releaseTag) async {
    // Determine platform
    String platform = Platform.operatingSystem;
    String arch = SysInfo.kernelArchitecture.toString().toLowerCase();
    String fileExt;
    switch (platform) {
      case "android":
        fileExt = "apk";
        break;
      //case "ios":
      //  fileExt = "";
      //  break;
      case "linux":
        throw Exception("Linux updates are handled via flatpak!");
      //case "macos":
      //  fileExt = "";
      //  break;
      //case "windows":
      //  fileExt = "";
      //  break;
      default:
        throw Exception("Unsupported platform");
    }
    logger.i("Downloading $releaseTag update for $platform-$arch.$fileExt");
    // To allow tracking download progress, send GET requests first
    // and then start downloading
    Uri binaryUri = Uri.parse("https://download.hedon-haven.top/$releaseTag/"
        "$platform-$arch.$fileExt");
    Uri checksumUri = Uri.parse("https://download.hedon-haven.top/"
        "$releaseTag/checksums.json");
    logger.i("GET-ting $binaryUri");
    final binaryResponse = await client.send(http.Request('GET', binaryUri));
    logger.i("GET-ting $checksumUri");
    final checksumResponse =
        await client.send(http.Request('GET', checksumUri));
    if (binaryResponse.reasonPhrase != "OK") {
      logger.e("Binary GET request failed, aborting update");
      throw Exception("Binary GET request failed");
    }
    if (checksumResponse.reasonPhrase != "OK") {
      logger.e("Checksum.json GET request failed, aborting update");
      throw Exception("Checksum.json GET request failed");
    }
    logger.i("Total binary download size: ${binaryResponse.contentLength}");

    int receivedDownload = 0;
    List<int> downloadedBytes = [];
    await for (var value in binaryResponse.stream) {
      downloadedBytes.addAll(value);
      receivedDownload += value.length;
      downloadProgress = receivedDownload / binaryResponse.contentLength!;
      notifyListeners();
    }
    // simply download checksum without tracking
    Map<String, dynamic> remoteChecksums = jsonDecode((await client.get(
            Uri.parse(
                "https://download.hedon-haven.top/$releaseTag/checksums.json")))
        .body);

    // Get the checksum for the corresponding binary
    String binaryChecksum = remoteChecksums["$platform-$arch.$fileExt"]!;

    // save to cache dir and install
    Directory dir = await getApplicationCacheDirectory();
    logger.i("Checking binary checksum");
    if (binaryChecksum != sha256.convert(downloadedBytes).toString()) {
      logger.e("Checksums do not match, aborting update");
      throw Exception("Checksums do not match");
    }
    logger.i("Checksums match, continuing update");
    logger.i("Saving update file to ${dir.path}/hedon_haven-update.$fileExt");
    await File('${dir.path}/hedon_haven-update.$fileExt')
        .writeAsBytes(downloadedBytes);
    logger.i("Prompting user to update");
    switch (platform) {
      case "android":
        await _installAndroid(dir.path);
        break;
      //case "ios":
      //  fileExt = "";
      //  break;
      case "linux":
        throw Exception("Linux updates are handled via flatpak!");
      //case "macos":
      //  fileExt = "";
      //  break;
      //case "windows":
      //  fileExt = "";
      //  break;
      default:
        throw Exception("Unsupported platform");
    }
  }

  Future<void> _installAndroid(String pathToBinary) async {
    try {
      await ApkInstaller.installApk(
          filePath: "$pathToBinary/hedon_haven-update.apk");
      logger.i("Apk installed");
    } catch (e) {
      logger.e("Android system failed to install update with: $e");
      rethrow;
    }
  }
}
