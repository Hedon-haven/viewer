# [Hedon haven (project website)](https://hedon-haven.top/)

An adult content aggregator app.

## Features:

* **Supports many Providers:** Supported providers include: Pornhub, xHamster and many more.
* **Completely Free:** Full access to all features with no hidden fees or subscriptions.
* **Offline viewing:** Download content for offline viewing from any provider.
* **Easy management:** Favorite videos, subscriptions, and watch history all in one place.
* **Privacy-Focused:** Designed with privacy-first principles to ensure data security and
  discretion.
* **Open Source:** Free and open-source, allowing anyone to contribute or verify the app security.
* **Modern Design:** A sleek and intuitive interface built with Flutter.
* **Supports all platforms:** iOS, Android, Windows, macOS, Linux, and Windows (Supported features
  may vary by platform).

## **[1.0 release roadmap](https://github.com/orgs/Hedon-haven/projects/1)**

## Building

1. Download and install the [flutter sdk](https://docs.flutter.dev/get-started/install)
2. Clone the repository: `git clone --depth=1 https://source.hedon-haven.top viewer`
3. Change directory: `cd viewer`
4. Get the dependencies: `flutter pub get`
5. Depending on your platform run:
    * Android:
        * `flutter build apk --debug` or `flutter build apk --release`
        * To build arch-specific: `flutter build apk --release --split-per-abi`
    * iOS: Not yet supported
    * Linux:
        * `flutter build linux --debug` or `flutter build linux --release`
    * Windows: Not yet supported
    * MacOS: Not yet supported

## Run tests

1. Download and install the [flutter sdk](https://docs.flutter.dev/get-started/install)
2. Clone the repository: `git clone --depth=1 https://source.hedon-haven.top viewer`
3. Change directory: `cd viewer`
4. Get the dependencies: `flutter pub get`
5. Generate mocks: `flutter pub run build_runner build`
6. Run the tests: `flutter test`

## Credit

* Search bar design inspired by [InnerTune](https://github.com/z-huang/InnerTune)
* Some widget code was adapted from [Revanced Manager](https://github.com/ReVanced/revanced-manager)
* Comments section & video gridview inspired by [LibreTube](https://libretube.dev/)