import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/utils/global_vars.dart';

Future<void> setDefaultSettings([forceReset = false]) async {
  if (await sharedStorage.containsKey("settings_version") && !forceReset) {
    if (await sharedStorage.getString("settings_version") ==
        packageInfo.version) {
      logger.i("Settings already set and using latest settings version");
      return;
    }
  }
  logger.i("Setting default settings");
  logger.w("Settings version changed from "
      "${(await sharedStorage.getString("settings_version"))} to "
      "${packageInfo.version}");
  await sharedStorage.setString("settings_version", packageInfo.version);
  await sharedStorage.setInt("icon_cache_counter", 5);

  // Do not reset dev options, as this should only be done from the settings_about screen
  if (!forceReset) {
    // force enable in debug mode
    logger.i("Setting dev options to $kDebugMode");
    await sharedStorage.setBool("enable_dev_options", kDebugMode);
  }
  await sharedStorage.setBool("enable_logging", false);
  await sharedStorage.setBool("onboarding_completed", false);

  await _setOfficialPluginSettings();
  await _setAppearanceSettings();
  await _setVideoAudioSettings();
  await _setCommentsSettings();
  await _setHistorySettings();
  await _setPrivacySettings();
  await setDefaultFilterSettings();
}

Future<void> _setOfficialPluginSettings() async {
  await sharedStorage.setStringList("results_providers", []);
  await sharedStorage.setStringList("homepage_providers", []);
  await sharedStorage.setStringList("search_suggestions_providers", []);
}

Future<void> _setAppearanceSettings() async {
  // Whether the app is concealed ("reminders" or "fake_settings") or default appearance ("Hedon haven")
  await sharedStorage.setString("launcher_appearance", "Hedon haven");
  // Fake reminders for app concealing
  await sharedStorage.setStringList("fake_reminders_list", [
    "Buy groceries",
    "Dentist appointment",
    "Pay electricity bill",
    "mom birthday"
  ]);
  // Fake gsm settings for app concealing
  await sharedStorage
      .setStringList("fake_settings_list", ["1", "0", "0", "1", "1"]);

  await sharedStorage.setString("theme_mode", "Follow device theme");
  await sharedStorage.setString("list_view", "Card");
  await sharedStorage.setBool("play_previews_video_list", true);
  await sharedStorage.setBool("homepage_enabled", true);
}

Future<void> _setVideoAudioSettings() async {
  await sharedStorage.setBool("start_in_fullscreen", false);
  await sharedStorage.setBool("auto_play", false);
  await sharedStorage.setBool("show_progress_thumbnails", true);
  await sharedStorage.setInt("preferred_video_quality", 2160); // 4K
  await sharedStorage.setInt("seek_duration", 10);
}

Future<void> _setCommentsSettings() async {
  await sharedStorage.setBool("comments_hide_hidden", false);
  await sharedStorage.setBool("comments_hide_negative", false);
  await sharedStorage.setBool("comments_filter_links", false);
  await sharedStorage.setBool("comments_filter_non_ascii", false);
}

Future<void> _setHistorySettings() async {
  await sharedStorage.setBool("enable_watch_history", true);
  await sharedStorage.setBool("enable_search_history", true);
}

Future<void> _setPrivacySettings() async {
  await sharedStorage.setBool("proxy_enabled", false);
  await sharedStorage.setString("proxy_address", "");
  await sharedStorage.setBool("hide_app_preview", true);
  await sharedStorage.setBool("keyboard_incognito_mode", true);
  await sharedStorage.setBool("show_external_link_warning", true);
}

Future<void> setDefaultFilterSettings() async {
  await sharedStorage.setString("sort_order", "Relevance");
  await sharedStorage.setBool("sort_reverse", false);
  await sharedStorage.setString("sort_date_range", "All time");
  await sharedStorage.setInt("sort_quality_min", 0);
  await sharedStorage.setInt("sort_quality_max", 2160);
  await sharedStorage.setInt("sort_duration_min", 0);
  await sharedStorage.setInt("sort_duration_max", 3600);
}

Future<ThemeMode> getThemeMode() async {
  switch ((await sharedStorage.getString("theme_mode"))!) {
    case "Follow device theme":
      return ThemeMode.system;
    case "Light theme":
      return ThemeMode.light;
    case "Dark theme":
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
