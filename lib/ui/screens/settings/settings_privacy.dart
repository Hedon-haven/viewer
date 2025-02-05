import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secure_app_switcher/secure_app_switcher.dart';

import '/ui/utils/toast_notification.dart';
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
                    FutureBuilder<bool?>(
                        future:
                            sharedStorage.getBool("privacy_hide_app_preview"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Hide app preview",
                              subTitle: "Hide app preview in app switcher",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async {
                                await sharedStorage.setBool(
                                    "privacy_hide_app_preview", value);
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
                    FutureBuilder<bool?>(
                        future: sharedStorage
                            .getBool("privacy_keyboard_incognito_mode"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Enable keyboard incognito mode",
                              subTitle:
                                  "Instruct keyboard app to enable incognito mode (e.g. disable auto-suggest, learning of new words, etc.)",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "privacy_keyboard_incognito_mode",
                                      value));
                        }),
                    FutureBuilder<bool?>(
                        future: sharedStorage
                            .getBool("privacy_show_external_link_warning"),
                        builder: (context, snapshot) {
                          return OptionsSwitch(
                              title: "Show external link warning",
                              subTitle:
                                  "Show a warning when opening an external link in default browser",
                              switchState: snapshot.data ?? true,
                              onToggled: (value) async =>
                                  await sharedStorage.setBool(
                                      "privacy_show_external_link_warning",
                                      value));
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
      await sharedStorage.setString("privacy_proxy_address", newValue);
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
                child: FutureBuilder<bool?>(
                    future: sharedStorage.getBool("privacy_proxy_enabled"),
                    builder: (context, proxyEnabled) {
                      return Column(children: <Widget>[
                        OptionsSwitch(
                            title: "Enable proxy",
                            subTitle: "Force all network requests to go through"
                                " the proxy",
                            switchState: proxyEnabled.data ?? false,
                            onToggled: (value) async {
                              await sharedStorage.setBool(
                                  "privacy_proxy_enabled", value);
                              setState(() {});
                            }),
                        FutureBuilder<String?>(
                            future: sharedStorage
                                .getString("privacy_proxy_address"),
                            builder: (context, snapshot) {
                              return ListTile(
                                enabled: proxyEnabled.data ?? false,
                                title: Text("Current proxy server"),
                                subtitle: Text(snapshot.data?.isEmpty ?? true
                                    ? "None set"
                                    : snapshot.data!),
                                trailing: Icon(Icons.edit),
                                onTap: () => setCustomProxy(snapshot.data!),
                              );
                            }),
                        ListTile(
                            enabled: proxyEnabled.data ?? false,
                            trailing: const Icon(Icons.bolt),
                            title: const Text("Find fastest proxy"),
                            onTap: () {
                              showToast("Not yet implemented", context);
                            }),
                        ListTile(
                            enabled: proxyEnabled.data ?? false,
                            trailing: const Icon(Icons.shuffle),
                            title: const Text("Find random proxy"),
                            onTap: () {
                              showToast("Not yet implemented", context);
                            })
                      ]);
                    }))));
  }
}
