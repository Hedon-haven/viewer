import 'dart:convert';
import 'dart:io';

import 'package:apk_installer/apk_installer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:system_info2/system_info2.dart';

import '/main.dart';

class UpdateManager extends ChangeNotifier {
  String? latestTag;
  String? latestChangeLog;
  double downloadProgress = 0.0;

  Future<List<String?>> checkForUpdate() async {
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
        await http.get(Uri.parse("https://changelog.hedon-haven.top/latest"));
    if (responseVersion.statusCode != 200) {
      throw Exception("Couldn't fetch latest version");
    }
    latestTag = responseVersion.body;
    // Get latest changelog
    final responseChangelog = await http
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
      logger.d("Remote version: $latestTag");
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
    logger.i("Downloading $releaseTag update");
    // To allow tracking download progress, send GET requests first
    // and then start downloading
    final apkResponse = await http.Client().send(http.Request(
        'GET',
        Uri.parse(
            "https://download.hedon-haven.top/$releaseTag/android-"
                "${SysInfo.kernelArchitecture.toString().toLowerCase()}.apk")));
    final checksumResponse = await http.Client().send(http.Request(
        'GET',
        Uri.parse(
            "https://download.hedon-haven.top/$releaseTag/checksums.json")));
    if (apkResponse.reasonPhrase != "OK") {
      logger.e("Apk GET request failed, aborting update");
      throw Exception("Apk GET request failed");
    }
    if (checksumResponse.reasonPhrase != "OK") {
      logger.e("Checksum.json GET request failed, aborting update");
      throw Exception("Checksum.json GET request failed");
    }
    logger.i("Total apk download size: ${apkResponse.contentLength}");

    int receivedDownload = 0;
    List<int> downloadedBytes = [];
    await for (var value in apkResponse.stream) {
      downloadedBytes.addAll(value);
      receivedDownload += value.length;
      downloadProgress = receivedDownload / apkResponse.contentLength!;
      notifyListeners();
    }
    // simply download checksum without tracking
    Map<String, dynamic> remoteChecksums = jsonDecode((await http.get(
            Uri.parse("https://download.hedon-haven.top/$releaseTag/checksums.json")))
        .body);

    // Get the checksum for the corresponding apk
    String apkChecksum = remoteChecksums[
        "android-${SysInfo.kernelArchitecture.toString().toLowerCase()}.apk"]!;

    // save to cache dir and install
    Directory dir = await getApplicationCacheDirectory();
    logger.i("Checking apk checksum");
    if (apkChecksum != sha256.convert(downloadedBytes).toString()) {
      logger.e("Checksums do not match, aborting update");
      throw Exception("Checksums do not match");
    }
    logger.i("Checksums match, continuing update");
    logger.i("Saving update file to ${dir.path}/hedon_haven-update.apk");
    await File('${dir.path}/hedon_haven-update.apk')
        .writeAsBytes(downloadedBytes);
    logger.i("Prompting user to update");
    try {
      await ApkInstaller.installApk(
          filePath: "${dir.path}/hedon_haven-update.apk");
      logger.i("Apk installed");
    } catch (e) {
      logger.e("Android system failed to install update with: $e");
      rethrow;
    }
  }
}
