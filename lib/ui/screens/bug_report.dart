import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_info2/system_info2.dart';

import '/services/bug_report_manager.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/alert_dialog.dart';
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
        "\t\tRunning on: ${Platform.operatingSystem}-"
        "${SysInfo.kernelArchitecture.toString().toLowerCase()}"
        " (${Platform.operatingSystemVersion})\n";
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
                  return ThemedDialog(
                    title: "Cancel bug report?",
                    primaryText: "Stay",
                    onPrimary: Navigator.of(context).pop,
                    secondaryText: "Cancel bug report",
                    onSecondary: () {
                      canPopYes = true;
                      // close popup
                      Navigator.pop(context);
                      // Go back a screen
                      Navigator.pop(context);
                    },
                  );
                });
          }
        },
        child: Scaffold(
            appBar: AppBar(
              // FIXME: This color changes when scrolling the the TextFields
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text("Bug Report"),
            ),
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: emptyDebugObject
                        ? ThemedDialog(
                            title: "Create empty bug report?",
                            primaryText: "Continue",
                            onPrimary: () =>
                                setState(() => emptyDebugObject = false),
                            secondaryText: "Go back",
                            onSecondary: Navigator.of(context).pop,
                            content: const Text(
                                "Long tap anything in the app to create a specific bug report.\n\n"
                                "Ignore this message if you want to create a suggestion."))
                        : submissionType == ""
                            ? buildSubmissionTypeDialog()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: buildMainList())))));
  }

  Widget buildSubmissionTypeDialog() {
    return ThemedDialog(
        title: "Select submission type",
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
    return ThemedDialog(
        title: "Select problem type",
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
