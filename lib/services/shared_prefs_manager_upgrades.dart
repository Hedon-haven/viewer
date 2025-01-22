/// Sometimes keys need to be renamed, deleted, changes, etc
/// For that here are functions which will help with that
/// To start an upgrade the current version is passed to startUpgrade()
/// startUpgrade will call the upgrade function with the current version
/// the functions are all chained -> theoretically its possible to upgrade from the first version to the last in one go
/// Some version functions are "missing", as not every upgrade requires changing something
/// However, in the main switch in startUpgrade every version should be present
/// This system is not designed to be robust and in case of failure all settings are just force-reset
library;

import '/utils/global_vars.dart';

bool startUpgrade(String currentVersion) {
  logger.w("Starting upgrade chain for $currentVersion");
  try {
    switch (currentVersion) {
      case "0.3.9":
        v0_3_10();
      case "0.3.10":
        v0_3_11();
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
  // No need to continue chain, as we are forcing a reset
}

// This is just a test update, nothing needs to actually be updated
void v0_3_11() {
  logger.i("Upgrading settings to 0.3.11");
}
