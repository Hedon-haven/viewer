import 'dart:convert';
import 'dart:io';

import 'package:apk_installer/apk_installer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:system_info2/system_info2.dart';

class UpdateManager extends ChangeNotifier {
  String? updateLink;
  String? latestChangeLog;
  double downloadProgress = 0.0;

  Future<List<String?>> checkForUpdate() async {
    // Check if connected to the internet
    if ((await (Connectivity().checkConnectivity()))
        .contains(ConnectivityResult.none)) {
      logger.w("No internet connection, canceling update check");
      return [updateLink, latestChangeLog];
    }

    // Get current version
    String localVersion = packageInfo.version;
    // get remote version
    final response = await http.get(Uri.parse(
        "https://api.github.com/repos/hedon-haven/viewer/releases/latest"));
    if (response.statusCode != 200) {
      logger.e(
          "ERROR: Couldnt fetch latest version information, canceling update");
      // TODO: Display error to user
      return [updateLink, latestChangeLog];
    }
    String remoteVersion = json.decode(response.body)['tag_name'].substring(1);
    latestChangeLog = json.decode(response.body)['body'];
    List<int> localVersionList = [];
    List<int> remoteVersionList = [];

    try {
      // convert to lists of integers
      logger.d("Attempting to convert versions to list of integers");
      logger.d("Current version: $localVersion");
      logger.d("Remote version: $remoteVersion");
      localVersionList = localVersion.split('.').map(int.parse).toList();
      remoteVersionList = remoteVersion.split('.').map(int.parse).toList();
    } on FormatException {
      logger.e(
          "ERROR: Unexpected version format (FORMAT_INVALID), canceling update");
      // TODO: Display error to user
      return [updateLink, latestChangeLog];
    }

    // make sure both lists are exactly 3 elements long
    if (localVersionList.length != 3 || remoteVersionList.length != 3) {
      logger.e(
          "ERROR: Unexpected version format (FORMAT_TOO_LONG), canceling update");
      // TODO: Display error to user
      return [updateLink, latestChangeLog];
    }

    // compare versions
    // if any part of the version is lower, update is available
    if (localVersionList[0] < remoteVersionList[0] ||
        localVersionList[1] < remoteVersionList[1] ||
        localVersionList[2] < remoteVersionList[2]) {
      logger.i("Local version is lower, update available");
      updateLink =
          "https://github.com/hedon-haven/viewer/releases/latest/download"
          "/${SysInfo.kernelArchitecture.toString().toLowerCase()}.apk";
    } else {
      logger.i("Local version matches remote version, no update available");
    }
    return [updateLink, latestChangeLog];
  }

  Future<void> downloadUpdate(String downloadLink) async {
    logger.i("Downloading update from $downloadLink");
    final response =
        await http.Client().send(http.Request('GET', Uri.parse(downloadLink)));
    if (response.contentLength == null) {
      logger.e("Download GET request failed, aborting update");
      return;
    }
    logger.i("Total download size: response.contentLength");

    int receivedDownload = 0;
    List<int> downloadedBytes = [];
    await for (var value in response.stream) {
      downloadedBytes.addAll(value);
      receivedDownload += value.length;
      downloadProgress = receivedDownload / response.contentLength!;
      notifyListeners();
    }

    // save to cache dir and install
    Directory dir = await getApplicationCacheDirectory();
    await File('${dir.path}/hedon_haven-update.apk')
        .writeAsBytes(downloadedBytes);
    logger.i("Saving update file to ${dir.path}/hedon_haven-update.apk");
    logger.i("Prompting user to update");
    try {
      await ApkInstaller.installApk(
          filePath: "${dir.path}/hedon_haven-update.apk");
    } catch (e) {
      logger.e("Android system failed to install update with: $e");
    }
  }
}
