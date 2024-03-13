import 'package:flutter/material.dart';
import 'package:hedon_viewer/main.dart';

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

  setDefaultSettings() {
    sharedStorage.setStringList("enabled_plugins", []);
    sharedStorage.setInt("preferred_video_quality", 2160); // 4K
    sharedStorage.setStringList("enabled_plugins", ["xHamster.com"]);
    sharedStorage.setString("theme_mode", "Follow device theme");
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
