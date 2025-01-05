import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_logger.dart';

final SharedPreferencesAsync sharedStorage = SharedPreferencesAsync();
// Store the value here, so that user only sees the warning once per session
bool thirdPartyPluginWarningShown = false;
final logger = Logger(
  printer: BetterSimplePrinter(),
  filter: VariableFilter(),
);
late PackageInfo packageInfo;

/// This stores the global setting of whether the preview should be hidden
bool hidePreview = true;
