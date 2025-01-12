import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedon_viewer/services/official_plugins_tracker.dart';
import 'package:hedon_viewer/utils/global_vars.dart';
import 'package:mockito/mockito.dart';

// Keep in mind this import wont work until "flutter pub run build_runner build" is run
import 'generate_mocks.mocks.dart';

// OfficialPlugins import some ui packages -> `dart run` wont work
// To be able to do this in headless mode (i.e. inside a CI action) use `flutter test`
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final mock = MockSharedPreferencesAsync();
  when(mock.getBool("enable_dev_options")).thenAnswer((_) async => false);
  sharedStorage = mock;

  test("", () async {
    // Get plugin names and join them with commas
    String content = (await getAllOfficialPlugins())
        .map((plugin) => plugin.codeName)
        .join(",");

    print(content);
  });
}
