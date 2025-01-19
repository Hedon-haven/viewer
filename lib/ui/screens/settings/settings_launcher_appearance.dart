import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

import '/ui/screens/settings/settings_plugins.dart';
import '/ui/utils/toast_notification.dart';
import '/ui/widgets/future_widget.dart';
import '/utils/global_vars.dart';

class LauncherAppearance extends StatefulWidget {
  final bool partOfOnboarding;
  final void Function()? setStateMain;

  const LauncherAppearance(
      {super.key, this.partOfOnboarding = false, this.setStateMain});

  @override
  State<LauncherAppearance> createState() => _LauncherAppearanceScreenState();
}

class _LauncherAppearanceScreenState extends State<LauncherAppearance> {
  // the actual default icon is called "stock" everywhere except here
  final List<String> list = ["default", "fake_settings", "reminders"];

  void handleOptionChange(String? value) async {
    if (kDebugMode || kProfileMode) {
      // FIXME: Report bug upstream or fix myself
      ToastMessageShower.showToast(
          "Doesn't work in Debug or Profile versions", context);
      return;
    }
    if (value != null) {
      // show dialog explaining the option if needed
      if (value != "Hedon haven") {
        await showDialog(
            context: context,
            builder: (BuildContext context) {
              // running setupAppIcon will force the app to quit. Ask user to confirm first
              return AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  title: Text(
                      value == "Reminders"
                          ? "Create a new reminder called \"Stop concealing\" to exit reminders mode."
                          : "Long press on \"Show signal strength in advanced mode\" to exit GSM Settings mode",
                      style: Theme.of(context).textTheme.titleMedium),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Ok"),
                    )
                  ]);
            });
      }
      setState(() {});
      showDialog(
          context: context,
          builder: (BuildContext context) {
            // running setupAppIcon will force the app to quit. Ask user to confirm first
            return AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                content: Text(
                    "App will now close and can be found again as \"$value\" in the launcher. "
                    "${widget.partOfOnboarding ? "\n\nThis will also complete the onboarding process." : ""}",
                    style: Theme.of(context).textTheme.titleMedium),
                actions: [
                  TextButton(
                    onPressed: () {
                      // close popup
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (widget.partOfOnboarding) {
                        logger.i("Onboarding completed");
                        await sharedStorage.setBool(
                            "onboarding_completed", true);
                      }
                      // close popup
                      Navigator.pop(context);
                      sharedStorage.setString("launcher_appearance", value);
                      switch (value) {
                        case "Hedon haven":
                          logger.i("Changing to stock icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "default", iconList: list);
                          break;
                        case "GSM Settings":
                          logger.i("Changing to GSM settings icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "fake_settings", iconList: list);
                          break;
                        case "Reminders":
                          logger.i("Changing to reminders icon");
                          DynamicAppIcon.setupAppIcon(
                              iconName: "reminders", iconList: list);
                          break;
                      }
                    },
                    child: const Text("Ok",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ]);
          });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // Hide back button in onboarding
          automaticallyImplyLeading: !widget.partOfOnboarding,
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: widget.partOfOnboarding
              ? Center(child: Text("Launcher appearance"))
              : const Text("Launcher appearance"),
        ),
        body: SafeArea(
            child: Column(children: [
          SingleChildScrollView(
              child: FutureWidget<String?>(
                  future: sharedStorage.getString("launcher_appearance"),
                  finalWidgetBuilder: (context, snapshotData) {
                    return Column(
                      children: [
                        ListTile(
                            title: const Text("Hedon haven"),
                            leading: const CircleAvatar(
                              foregroundImage:
                                  AssetImage("assets/launcher-icon/stock.png"),
                              backgroundColor: Colors.white,
                            ),
                            trailing: Radio(
                              value: "Hedon haven",
                              groupValue: snapshotData,
                              onChanged: handleOptionChange,
                            )),
                        const SizedBox(height: 10),
                        ListTile(
                            title: const Text("GSM Settings"),
                            leading: const CircleAvatar(
                              foregroundImage: AssetImage(
                                  "assets/launcher-icon/fake_settings.png"),
                              backgroundColor: Colors.white,
                            ),
                            trailing: Radio(
                              value: "GSM Settings",
                              groupValue: snapshotData,
                              onChanged: handleOptionChange,
                            )),
                        const SizedBox(height: 10),
                        ListTile(
                            title: const Text("Reminders"),
                            leading: const CircleAvatar(
                              foregroundImage: AssetImage(
                                  "assets/launcher-icon/reminders.png"),
                              backgroundColor: Colors.white,
                            ),
                            trailing: Radio(
                              value: "Reminders",
                              groupValue: snapshotData,
                              onChanged: handleOptionChange,
                            ))
                      ],
                    );
                  })),
          if (widget.partOfOnboarding) ...[
            Spacer(),
            Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Align(
                      alignment: Alignment.bottomLeft,
                      child: ElevatedButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant),
                          onPressed: () => Navigator.push(
                              context,
                              PageTransition(
                                  type: PageTransitionType.leftToRightJoined,
                                  childCurrent: widget,
                                  child: PluginsScreen(
                                      partOfOnboarding: true,
                                      setStateMain: widget.setStateMain!))),
                          child: Text("Back",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)))),
                  Spacer(),
                  Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary),
                          onPressed: () async {
                            logger.i("Onboarding completed");
                            await sharedStorage.setBool(
                                "onboarding_completed", true);
                            // Force redraw of main screen to exit onboarding
                            widget.setStateMain!();
                            // Go back to main screen
                            await Navigator.pushNamedAndRemoveUntil(
                                context, "/", (route) => false);
                          },
                          child: Text("Finish onboarding",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary))))
                ]))
          ]
        ])));
  }
}
