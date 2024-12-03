import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '/main.dart';

class BugReportManager {
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void submitReport(String submissionType, String issueType,
      String generatedBody, String userInput) async {
    switch (submissionType) {
      case "Anonymous report":
        logger.w("Anonymous reports not yet implemented");
        break;
      case "Private email report":
        logger.i("Opening email client");
        await launchUrl(Uri(
          scheme: 'mailto',
          path: 'hedon-haven.7qw93@8shield.net',
          query: encodeQueryParameters(<String, String>{
            'subject': issueType,
            'body': "$generatedBody\n\nAdditional information: \n$userInput"
          }),
        ));
      case "Public github report":
        // switch (issueType) {
        //
        // }
        await Clipboard.setData(ClipboardData(
            text: "$generatedBody\n\nAdditional information: \n$userInput"));
        await launchUrl(
            Uri.parse("https://github.com/hedon-haven/viewer/issues"));
        break;
    }
  }
}
