import 'package:hedon_viewer/plugins/xhamster.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsManager {
  // Due to being async, the SharedPreferences instance is a bit unreliable (sometime takes too long to initialize and set value)
  // -> Pre-initialize the SharedPreferences instance to at least avoid waiting for it to initialize
  // make the settings manager a singleton.
  // This way any part of the app can access the settings, without having to re-initialize the SharedPreferences instance
  // also, this basically converts the SharedPrefs from async to sync, which prevents settings loss
  static final SharedPrefsManager _instance = SharedPrefsManager._init();

  SharedPrefsManager._init() {
    _getSharedPrefsInstance();
  }

  factory SharedPrefsManager() {
    return _instance;
  }

  late SharedPreferences preferencesInstance;

  void _getSharedPrefsInstance() async {
    preferencesInstance = await SharedPreferences.getInstance();
  }

  void _setDefaultSettings() {
    // set default settings
    preferencesInstance.setStringList("enabled_plugins", []);
    preferencesInstance.setInt("preferred_video_quality", 2160); // 4K
    preferencesInstance.setStringList("enabled_plugins", ["xHamster.com"]);
  }

  void setString(String key, String value) {
    preferencesInstance.setString(key, value);
  }

  void remove(String key) {
    preferencesInstance.remove(key);
  }

  Object? get(String key) {
    return preferencesInstance.get(key);
  }

  bool? getBool(String key) {
    return preferencesInstance.getBool(key);
  }

  int? getInt(String key) {
    return preferencesInstance.getInt(key);
  }

  List<String>? getStringList(key) {
    return preferencesInstance.getStringList(key);
  }
}
