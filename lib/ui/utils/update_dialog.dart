import 'package:flutter/material.dart';

import '/services/update_manager.dart';
import '/ui/widgets/alert_dialog.dart';
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
              body: PopScope(
                  canPop: false,
                  // Do not allow the user to close the dialog
                  onPopInvoked: (_) {},
                  child: ThemedDialog(
                    title: _updateFailed ? "Update failed" : "Update available",
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
                                          : updateManager.downloadProgress ==
                                                  1.0
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
                            Text(
                                "Latest changelog for ${updateManager.latestTag}: ",
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)))
                          ],
                        )
                      ],
                      if (_isDownloadingUpdate && !_updateFailed) ...[
                        LinearProgressIndicator(
                            value: updateManager.downloadProgress)
                      ]
                    ]),
                    // Only show buttons if update is not downloading
                    primaryText: _isDownloadingUpdate
                        ? null
                        : _updateFailed
                            ? "Ok"
                            : "Install update",
                    onPrimary: () async {
                      if (!_isDownloadingUpdate && !_updateFailed) {
                        setState(() => _isDownloadingUpdate = true);
                        logger.i("Starting update");
                        try {
                          await updateManager.downloadAndInstallUpdate(
                              updateManager.latestTag!);
                        } catch (e, stacktrace) {
                          logger.e("Update failed with: $e\n$stacktrace");
                          setState(() {
                            _isDownloadingUpdate = false;
                            _updateFailed = true;
                            _failReason = "$e\n$stacktrace";
                          });
                        }
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    secondaryText: _isDownloadingUpdate || _updateFailed
                        ? null
                        : "Install later",
                    onSecondary: Navigator.of(context).pop,
                  )));
        });
      });
}
