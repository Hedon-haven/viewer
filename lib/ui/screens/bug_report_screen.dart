import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_info2/system_info2.dart';

import '/services/bug_report_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/utils/global_vars.dart';

class BugReportScreen extends StatefulWidget {
  final Map<String, dynamic> debugObject;

  const BugReportScreen({super.key, required this.debugObject});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  String submissionType = "";
  String issueType = "";
  TextEditingController generatedController = TextEditingController();
  TextEditingController userInputController = TextEditingController();
  bool canPopYes = false;
  bool emptyDebugObject = true;

  List<String> submissionTypes = [
    "Anonymous report",
    "Private email report",
    "Public github report"
  ];

  List<String> submissionTypesSubtitles = [
    "Send and forget. Report will be fully anonymous. Least useful option for the developers.",
    "Use email to send a report. Developers might contact you if needed. Only use this option if you are able to respond to emails, otherwise use 'Anonymous report'. Your report may get anonymized and converted into a GitHub issue.",
    "Create a public github issue. Most useful option, as not only active maintainers will be able to help."
  ];

  List<String> issueTypes = [
    "Graphical glitch",
    "Performance issue",
    "Plugin issue",
    "Functional issue",
    "UI/UX suggestion",
    "Other"
  ];

  List<String> issueTypesSubtitles = [
    "Purely graphical glitches. E.g. overlapping widgets, too big/small widgets, etc.",
    "Use this option if you can pin-point the exact cause of a performance issue.",
    "For issues that are likely related to plugins (aka websites) and not to the application itself.",
    "For issues that are directly related to the functionality of the app.",
    "Suggestions for improving the UI/UX of the app. If you have a specific UI ISSUE, use the Graphical glitch option instead.",
    "For issues that dont fit into any of the above categories."
  ];

  String getAppInfo() {
    return "App info:\n"
        "\t\t${packageInfo.packageName}: v${packageInfo.version}\n"
        "\t\tInstalled from: ${packageInfo.installerStore}\n"
        "\t\tSignature: ${packageInfo.buildSignature}\n"
        "\t\tRunning on: ${Platform.operatingSystem}-${SysInfo.kernelArchitecture.toString().toLowerCase()}: ${Platform.operatingSystemVersion}\n";
  }

  String convertDebugObject() {
    return "\nDebug object:\n"
        "${widget.debugObject.entries.map((entry) => '\t\t${entry.key}: ${entry.value}').join('\n')}";
  }

  @override
  initState() {
    super.initState();
    emptyDebugObject = widget.debugObject.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: canPopYes,
        onPopInvoked: (goingToPop) {
          if (!goingToPop) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return buildExitDialog();
                });
          }
        },
        child: Scaffold(
            appBar: AppBar(
              title: const Text("Bug Report"),
            ),
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: emptyDebugObject
                        ? buildEmptyDialog()
                        : submissionType == ""
                            ? buildSubmissionTypeDialog()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: buildMainList())))));
  }

  Widget buildExitDialog() {
    return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Text("Cancel bug report?"),
        content: const Text(
            "Are you sure you want to cancel? Proper bug reports can help"
            " immensely in improving the app."),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface),
            child: Text("Cancel bug report",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            onPressed: () {
              canPopYes = true;
              // close popup
              Navigator.pop(context);
              // Go back a screen
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            child: Text("Stay",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
            // close popup
            onPressed: () => Navigator.pop(context),
          )
        ]);
    ;
  }

  Widget buildEmptyDialog() {
    return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Text("Create empty bug report?"),
        content: const Text(
            "Long tap anything in the app to create a specific bug report.\n\n"
            "Ignore this message if you want to create a suggestion."),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface),
            // Go back a screen
            onPressed: () => Navigator.pop(context),
            child: Text("Go back",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () => setState(() => emptyDebugObject = false),
            child: Text("Continue",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          )
        ]);
  }

  Widget buildSubmissionTypeDialog() {
    return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Text("Select submission type"),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              submissionTypes.length,
              (index) => ListTile(
                title: Text(submissionTypes[index]),
                subtitle: Text(submissionTypesSubtitles[index]),
                onTap: () {
                  setState(() {
                    if (submissionTypes[index] == "Anonymous report") {
                      showToast("Anonymous reports not yet supported", context);
                      return;
                    }
                    submissionType = submissionTypes[index];
                  });
                },
              ),
            )));
  }

  Widget buildIssueTypeDialog() {
    return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Text("Select problem type"),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              issueTypes.length,
              (index) => ListTile(
                title: Text(issueTypes[index]),
                subtitle: Text(issueTypesSubtitles[index]),
                onTap: () {
                  setState(() {
                    issueType = issueTypes[index];
                    generatedController.text =
                        getAppInfo() + convertDebugObject();
                  });
                },
              ),
            )));
  }

  List<Widget> buildMainList() {
    return [
      ListTile(
          title: const Text("Submission type"),
          subtitle: Text(submissionType),
          onTap: () => setState(() => submissionType = "")),
      const SizedBox(height: 4),
      issueType == ""
          ? buildIssueTypeDialog()
          : ListTile(
              title: const Text("Problem type"),
              subtitle: Text(issueType),
              onTap: () => setState(() => issueType = "")),
      const SizedBox(height: 4),
      if (submissionType != "" && issueType != "") ...[
        ListTile(
          title: Text("Auto-generated report: ",
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 16, right: 20),
                child: TextFormField(
                    controller: generatedController,
                    readOnly: true,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface), // Set border color
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface), // Set border color
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface), // Set border color
                      ),
                    )))),
        ListTile(
          title: Text("Additional information: ",
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 16, right: 20),
                child: TextField(
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    controller: userInputController,
                    decoration: InputDecoration(
                      hintText: "Any other relevant context for the problem: ",
                      border: const OutlineInputBorder(),
                      disabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    )))),
        Center(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                    ),
                    onPressed: () => submitReport(
                          submissionType,
                          issueType,
                          generatedController.text,
                          userInputController.text,
                        ),
                    child: Text("Submit report",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                                color:
                                    Theme.of(context).colorScheme.onPrimary)))))
      ]
    ];
  }
}
