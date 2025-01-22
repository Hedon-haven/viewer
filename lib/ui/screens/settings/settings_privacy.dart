import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';

import '/ui/utils/toast_notification.dart';
import '/ui/widgets/future_widget.dart';
import '/ui/widgets/options_switch.dart';
import '/utils/global_vars.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Privacy"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: <Widget>[
                    FutureWidget<bool?>(
                        future: sharedStorage.getBool("hide_app_preview"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Hide app preview",
                              subTitle: "Hide app preview in app switcher",
                              switchState: snapshotData!,
                              onToggled: (value) async {
                                await sharedStorage.setBool(
                                    "hide_app_preview", value);
                                // Force an immediate update
                                if (Platform.isAndroid || Platform.isIOS) {
                                  if (!value) {
                                    SecureAppSwitcher.off();
                                  } else {
                                    SecureAppSwitcher.on();
                                  }
                                }
                                // the hidePreview var is from main.dart
                                setState(() => hidePreview = value);
                              });
                        }),
                    FutureWidget<bool?>(
                        future:
                            sharedStorage.getBool("keyboard_incognito_mode"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Enable keyboard incognito mode",
                              subTitle:
                                  "Instruct keyboard app to enable incognito mode (e.g. disable auto-suggest, learning of new words, etc.)",
                              switchState: snapshotData!,
                              onToggled: (value) async => await sharedStorage
                                  .setBool("keyboard_incognito_mode", value));
                        }),
                    FutureWidget<bool?>(
                        future:
                            sharedStorage.getBool("show_external_link_warning"),
                        finalWidgetBuilder: (context, snapshotData) {
                          return OptionsSwitch(
                              title: "Show external link warning",
                              subTitle:
                                  "Show a warning when opening an external link in default browser",
                              switchState: snapshotData!,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "show_external_link_warning", value));
                        }),
                    ListTile(
                        trailing: Icon(Icons.arrow_forward),
                        title: const Text("Proxy settings"),
                        subtitle:
                            const Text("Enable/disable proxy, choose proxy"),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProxyScreen())))
                  ],
                ))));
  }
}

class ProxyScreen extends StatefulWidget {
  const ProxyScreen({super.key});

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  void setCustomProxy(String proxy) async {
    TextEditingController textController = TextEditingController(text: proxy);

    String? newValue = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            title: Text("Set custom proxy server (ip:port)"),
            content: TextField(
                controller: textController,
                decoration:
                    InputDecoration(hintText: "e.g. 256.256.256.256:8080")),
            actions: [
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface),
                child: Text("Cancel",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface),
                child: Text("Save",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                onPressed: () => Navigator.of(context).pop(textController.text),
              )
            ]);
      },
    );

    if (newValue != null) {
      await sharedStorage.setString("proxy_address", newValue);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.primary),
          title: const Text("Privacy"),
        ),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: FutureWidget<bool?>(
                    future: sharedStorage.getBool("proxy_enabled"),
                    finalWidgetBuilder: (context, proxyEnabled) {
                      return Column(children: <Widget>[
                        OptionsSwitch(
                            title: "Enable proxy",
                            subTitle: "Force all network requests to go through"
                                " the proxy",
                            switchState: proxyEnabled!,
                            onToggled: (value) async {
                              await sharedStorage.setBool(
                                  "proxy_enabled", value);
                              setState(() {});
                            }),
                        FutureWidget<String?>(
                            future: sharedStorage.getString("proxy_address"),
                            finalWidgetBuilder: (context, snapshotData) {
                              return ListTile(
                                enabled: proxyEnabled,
                                title: Text("Current proxy server"),
                                subtitle: Text(snapshotData!.isEmpty
                                    ? "None set"
                                    : snapshotData),
                                trailing: Icon(Icons.edit),
                                onTap: () => setCustomProxy(snapshotData),
                              );
                            }),
                        ListTile(
                            enabled: proxyEnabled,
                            trailing: const Icon(Icons.bolt),
                            title: const Text("Find fastest proxy"),
                            onTap: () {
                              ToastMessageShower.showToast(
                                  "Not yet implemented", context);
                            }),
                        ListTile(
                            enabled: proxyEnabled,
                            trailing: const Icon(Icons.shuffle),
                            title: const Text("Find random proxy"),
                            onTap: () {
                              ToastMessageShower.showToast(
                                  "Not yet implemented", context);
                            })
                      ]);
                    }))));
  }
}
