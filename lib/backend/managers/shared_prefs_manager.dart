import 'package:flutter/material.dart';

import '/main.dart';

// Shared preferences can only store strings, ints and lists
// Sometimes it is necessary to store other types
// This class is a converter from string/into to other types
class SharedPrefsManager {
  // make the shared prefs manager a singleton.
  // This way any part of the app can access the settings, without having to re-initialize the manager
  static final SharedPrefsManager _instance = SharedPrefsManager._init();

  SharedPrefsManager._init() {
    setDefaultSettings();
  }

  factory SharedPrefsManager() {
    return _instance;
  }

  void setDefaultSettings([forceReset = false]) {
    if (sharedStorage.containsKey("settings_version") && !forceReset) {
      if (sharedStorage.getString("settings_version") == packageInfo.version) {
        return;
      }
    }
    logger.w(
        "Settings version changed from ${sharedStorage.getString("settings_version")} to ${packageInfo.version}");
    logger.i("Setting default settings");
    // TODO: Implement not overriding settings
    setDefaultFilterSettings();
    sharedStorage.setBool("enable_dev_options", false);
    sharedStorage.setString("settings_version", packageInfo.version);
    sharedStorage.setString("app_appearance", "Hedon haven");
    sharedStorage.setBool("start_in_fullscreen", false);
    sharedStorage.setBool("homepage_enabled", false);
    sharedStorage.setBool("auto_play", false);
    sharedStorage.setInt("preferred_video_quality", 2160); // 4K
    sharedStorage.setInt("seek_duration", 10);
    sharedStorage.setStringList("enabled_plugins", ["xHamster.com"]);
    sharedStorage.setString("search_provider", "xHamster.com");
    sharedStorage.setStringList("homepage_providers", ["xHamster.com"]);
    sharedStorage.setString("theme_mode", "Follow device theme");
    sharedStorage.setBool("play_previews_video_list", true);
    sharedStorage.setString("list_view", "Card");
  }

  void setDefaultFilterSettings() {
    sharedStorage.setString("sort_order", "Relevance");
    sharedStorage.setBool("sort_reverse", false);
    sharedStorage.setString("sort_date_range", "All time");
    sharedStorage.setInt("sort_quality_min", 0);
    sharedStorage.setInt("sort_quality_max", 2160);
    sharedStorage.setInt("sort_duration_min", 0);
    sharedStorage.setInt("sort_duration_max", 3600);
  }

  getThemeMode() {
    switch (sharedStorage.getString("theme_mode")) {
      case "Follow device theme":
        return ThemeMode.system;
      case "Light theme":
        return ThemeMode.light;
      case "Dark theme":
        return ThemeMode.dark;
    }
  }
}
