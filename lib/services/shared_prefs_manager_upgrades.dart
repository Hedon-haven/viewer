/// Sometimes keys need to be renamed, deleted, changes, etc
/// For that here are functions which will help with that
/// To start an upgrade the current version is passed to startUpgrade()
/// startUpgrade will call the upgrade function with the current version
/// the functions are all chained -> theoretically its possible to upgrade from
/// the first version to the last in one go
/// This system is not designed to be extremely robust and in case of failure all settings are just force-reset
library;

import '/utils/global_vars.dart';

bool startUpgrade(String currentVersion) {
  logger.w("Starting upgrade chain for $currentVersion");
  try {
    switch (currentVersion) {
      case "0.3.9":
        v0_3_10();
      default:
        logger.e("Unknown version: $currentVersion. Not changing anything");
        return true;
    }
  } catch (e, stacktrace) {
    logger.e("Error upgrading settings: $e\n$stacktrace");
    return false;
  }
  return true;
}

// All settings were renamed in the 0.3.10 update -> force reset everything
void v0_3_10() {
  logger.i("Upgrading settings to 0.3.10");
  throw Exception("Forcing a full settings reset");
}
