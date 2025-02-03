import 'package:flutter/material.dart';

import '/services/update_manager.dart';
import '/utils/global_vars.dart';

bool _updateFailed = false;
String? _failReason;
bool _isDownloadingUpdate = false;

void showUpdateDialog(UpdateManager updateManager, BuildContext parentContext) {
  showDialog(
      context: parentContext,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          // This is for showing the download progress
          updateManager.addListener(() => setState(() {}));
          return Scaffold(
              body: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            title: const Center(child: Text("Update available")),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: !_updateFailed
                      ? const EdgeInsets.only(bottom: 20)
                      : EdgeInsets.zero,
                  child: Text(
                      _updateFailed
                          ? "Update failed due to $_failReason\n\nPlease try again later."
                          : _isDownloadingUpdate
                              ? updateManager.downloadProgress == 0.0
                                  ? "Fetching update metadata..."
                                  : updateManager.downloadProgress == 1.0
                                      ? "Installing update..."
                                      : "Downloading update..."
                              : "Please install the update to continue",
                      style: Theme.of(context).textTheme.titleMedium)),
              if (updateManager.latestChangeLog != null &&
                  !_isDownloadingUpdate &&
                  !_updateFailed) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Latest changelog for ${updateManager.latestTag}: ",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Text(updateManager.latestChangeLog!,
                                style: Theme.of(context).textTheme.bodySmall)))
                  ],
                )
              ],
              if (_isDownloadingUpdate && !_updateFailed) ...[
                LinearProgressIndicator(value: updateManager.downloadProgress)
              ]
            ]),
            actions: <Widget>[
              // This row is needed for the spacer to work
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                if (!_isDownloadingUpdate || _updateFailed) ...[
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_updateFailed ? "Ok" : "Install later"),
                  ),
                  if (!_updateFailed) ...[
                    Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // TODO: Fix background color of button
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onPressed: () async {
                        if (!_isDownloadingUpdate) {
                          setState(() => _isDownloadingUpdate = true);
                          logger.i("Starting update");
                          try {
                            await updateManager.downloadAndInstallUpdate(
                                updateManager.latestTag!);
                          } catch (e, stacktrace) {
                            logger.e("Update failed with: $e\n$stacktrace");
                            setState(() {
                              _updateFailed = true;
                              _failReason = e.toString();
                            });
                          }
                        }
                      },
                      child: Text("Update and install",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary)),
                    )
                  ]
                ]
              ])
            ],
          ));
        });
      });
}
