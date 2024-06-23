import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hedon_viewer/backend/managers/bug_report_manager.dart';
import 'package:hedon_viewer/main.dart';
import 'package:hedon_viewer/ui/toast_notification.dart';

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
    "Use email to send a report. Developers might contact you if needed. Only use this option if you are able to respond to emails, otherwise use 'Anonymous report'. Your report may get anonymized converted into a GitHub issue.",
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
        "\t\tRunning on: ${Platform.operatingSystemVersion}\n";
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
                  return AlertDialog(
                      title: const Text("Cancel bug report?"),
                      content: const Text(
                          "Are you sure you want to cancel? Proper bug reports can help"
                          " immensely in improving the app."),
                      actions: [
                        TextButton(
                          onPressed: () {
                            canPopYes = true;
                            // close popup
                            Navigator.pop(context);
                            // Go back a screen
                            Navigator.pop(context);
                          },
                          child: const Text("Confirm cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            // close popup
                            Navigator.pop(context);
                          },
                          child: const Text("Go back to bug report",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ]);
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
                        ? AlertDialog(
                            title: const Text("Create empty bug report?"),
                            content: const Text(
                                "Long tap anything in the app to create a specific bug report.\n"
                                "Ignore this message if you want to create a suggestion."),
                            actions: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      emptyDebugObject = false;
                                    });
                                  },
                                  child: const Text("Create empty report"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Go back a screen
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Go back",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                )
                              ])
                        : submissionType == ""
                            ? AlertDialog(
                                title: const Text("Select submission type"),
                                content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      submissionTypes.length,
                                      (index) => ListTile(
                                        title: Text(submissionTypes[index]),
                                        subtitle: Text(
                                            submissionTypesSubtitles[index]),
                                        onTap: () {
                                          setState(() {
                                            submissionType =
                                                submissionTypes[index];
                                          });
                                        },
                                      ),
                                    )))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    ListTile(
                                        title: const Text("Submission type"),
                                        subtitle: Text(submissionType),
                                        onTap: () {
                                          setState(() {
                                            submissionType = "";
                                          });
                                        }),
                                    const SizedBox(height: 4),
                                    issueType == ""
                                        ? AlertDialog(
                                            title: const Text(
                                                "Select problem type"),
                                            content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: List.generate(
                                                  issueTypes.length,
                                                  (index) => ListTile(
                                                    title:
                                                        Text(issueTypes[index]),
                                                    subtitle: Text(
                                                        issueTypesSubtitles[
                                                            index]),
                                                    onTap: () {
                                                      setState(() {
                                                        issueType =
                                                            issueTypes[index];
                                                        generatedController
                                                                .text =
                                                            getAppInfo() +
                                                                convertDebugObject();
                                                      });
                                                    },
                                                  ),
                                                )))
                                        : ListTile(
                                            title: const Text("Problem type"),
                                            subtitle: Text(issueType),
                                            onTap: () {
                                              setState(() {
                                                issueType = "";
                                              });
                                            }),
                                    const SizedBox(height: 4),
                                    if (submissionType != "" &&
                                        issueType != "") ...[
                                      ListTile(
                                        title: Text("Auto-generated report: ",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ),
                                      Expanded(
                                          child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 20,
                                                  left: 16,
                                                  right: 20),
                                              child: TextFormField(
                                                  controller:
                                                      generatedController,
                                                  readOnly: true,
                                                  maxLines: null,
                                                  expands: true,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  textAlignVertical:
                                                      TextAlignVertical.top,
                                                  decoration:
                                                      const InputDecoration(
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Colors
                                                              .white), // Set border color
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Colors
                                                              .white), // Set border color
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color: Colors
                                                              .white), // Set border color
                                                    ),
                                                  )))),
                                      ListTile(
                                        title: Text("Additional information: ",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ),
                                      Expanded(
                                          child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 20,
                                                  left: 16,
                                                  right: 20),
                                              child: TextField(
                                                  maxLines: null,
                                                  expands: true,
                                                  textAlignVertical:
                                                      TextAlignVertical.top,
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  controller:
                                                      userInputController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Any other relevant context for the problem: ",
                                                    border:
                                                        const OutlineInputBorder(),
                                                    disabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary),
                                                    ),
                                                  )))),
                                      Center(
                                          child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: ElevatedButton(
                                                  // TODO: Customize background without overriding animation
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 40,
                                                        vertical: 20),
                                                  ),
                                                  onPressed: () {
                                                    if (submissionType ==
                                                        "Anonymous report") {
                                                      ToastMessageShower.showToast(
                                                          "Not yet supported", context);
                                                    } else {
                                                      BugReportManager()
                                                          .submitReport(
                                                        submissionType,
                                                        issueType,
                                                        generatedController
                                                            .text,
                                                        userInputController
                                                            .text,
                                                      );
                                                    }
                                                  },
                                                  child: Text("Submit report",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium!
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onPrimary)))))
                                    ]
                                  ])))));
  }
}
