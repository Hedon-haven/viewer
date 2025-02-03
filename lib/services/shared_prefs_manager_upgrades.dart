/// Sometimes keys need to be renamed, deleted, changes, etc
/// For that here are functions which will help with that
/// To start an upgrade the current version is passed to startUpgrade()
/// startUpgrade will call the correct function for the current version
/// the functions are all chained -> theoretically its possible to upgrade from the first version to the last in one go
/// Some version functions are "missing", as not every upgrade requires changing something
/// However, in the main switch in startUpgrade every version should be present
/// This system is NOT designed to be robust and in case of failure all settings are just force-reset
library;

import '/utils/global_vars.dart';

Future<bool> startUpgrade(String currentVersion) async {
  logger.w("Starting upgrade chain for $currentVersion");
  try {
    switch (currentVersion) {
      case "0.3.9":
        await v0_3_10();
        break;
      case "0.3.10":
        break;
      case "0.3.11":
        break;
      case "0.3.12":
        await v0_3_13();
        break;
      case "0.3.13":
        break;
      case "0.3.14":
        break;
      default:
        logger.e("Unknown version: $currentVersion. Not changing anything");
    }
  } catch (e, stacktrace) {
    logger.e("Error upgrading settings: $e\n$stacktrace");
    return false;
  }
  return true;
}

// All settings were renamed in the 0.3.10 update -> force reset everything
Future<void> v0_3_10() async {
  logger.i("Upgrading settings to 0.3.10");
  throw Exception("Forcing a full settings reset");
  // No need to continue chain, as we are forcing a reset
}

// plugins_$type_providers was changed to plugins_$type
Future<void> v0_3_13() async {
  logger.i("Upgrading settings to 0.3.13");
  List<String>? results =
      await sharedStorage.getStringList("plugins_results_providers");
  if (results != null) {
    logger.d("Renaming plugins_results_providers to plugins_results");
    await sharedStorage.setStringList("plugins_results", results);
  }

  List<String>? homepage =
      await sharedStorage.getStringList("plugins_homepage_providers");
  if (homepage != null) {
    logger.d("Renaming plugins_homepage_providers to plugins_homepage");
    await sharedStorage.setStringList("plugins_homepage", homepage);
  }

  List<String>? searchSuggestions =
      await sharedStorage.getStringList("plugins_search_suggestions_providers");
  if (searchSuggestions != null) {
    logger.d(
        "Renaming plugins_search_suggestions_providers to plugins_search_suggestions");
    await sharedStorage.setStringList(
        "plugins_search_suggestions", searchSuggestions);
  }
}
