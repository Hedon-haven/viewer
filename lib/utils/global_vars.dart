import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/http_manager.dart';
import 'custom_logger.dart';

// Make these late-initialized to allow mocking them in tests
late SharedPreferencesAsync sharedStorage;
late Logger logger;
late PackageInfo packageInfo;
late http.Client client;

/// This stores the global setting of whether the preview should be hidden
bool hidePreview = true;

// Make this bool a global var, -> user only sees the warning once per session
bool thirdPartyPluginWarningShown = false;

// Each initialization is a separate function to allow mocking only some parts
// of the app
Future<void> initGlobalVars() async {
  await initSharedStorage();
  await initLogger();
  await initPackageInfo();
  await initHttpClient();
}

Future<void> initSharedStorage() async {
  sharedStorage = SharedPreferencesAsync();
}

Future<void> initLogger() async {
  logger = Logger(
    printer: BetterSimplePrinter(),
    filter: VariableFilter(),
  );
}

Future<void> initPackageInfo() async {
  packageInfo = await PackageInfo.fromPlatform();
}

Future<void> initHttpClient() async {
  logger.i("Initializing http client");
  String? proxy = await sharedStorage.getString("proxy_address");
  logger.i("Using proxy: $proxy");
  client = getHttpClient(proxy);
}
