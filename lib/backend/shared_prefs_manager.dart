import 'package:hedon_viewer/main.dart';

class SharedPrefsManager {
  SharedPrefsManager() {
    print("Setting default settings");
    localStorage.setStringList("enabled_plugins", []);
    localStorage.setInt("preferred_video_quality", 2160); // 4K
    localStorage.setStringList("enabled_plugins", ["xHamster.com"]);
  }
}
