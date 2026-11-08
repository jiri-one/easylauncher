# EasyLauncher

**English** | [Čeština](README.cs.md)

A lightweight Android launcher designed primarily for phones with monochrome e-ink displays. Black text on a white background, large tiles without icons, and transitions without animations.

## Project status

Version **0.1.1 is the first public build**. The app has been tested on a physical **Bigme HiBreak Pro BW running Android 14**, including a system font scale of 180%.

Daily use is now beginning. Bug fixes and usability improvements will follow from that experience; additional features may be added later as real needs emerge. EasyLauncher will always remain lightweight and simple.

## Controls

- Tap the clock to open alarms, or the date to open your selected calendar.
- Favorite apps use two columns by default. Long press a tile to rename, remove, or reorder it. When renaming, Enter inserts a line break; use **Uložit** (Save) to save the name.
- Swipe up to open an alphabetical list of the remaining apps, with search that ignores diacritics. Swipe down at the top of the list or across its header to return to favorites and close the keyboard. Long press an app to add it to favorites.
- Swipe from right to left to open the camera, from left to right to open contacts, and down on the home screen to open notifications. Gestures also work over tiles; the favorites grid can scroll when there are more favorites or longer names spanning multiple lines.
- Settings let you change target apps, the number of columns, label size, and whether the keyboard opens automatically. The system Home button returns to the home screen and closes search and the keyboard.

You can select EasyLauncher as your default home app from its settings. To use the notification gesture, enable its service in Android's accessibility settings. The service only opens the notification shade; it does not read its contents or the contents of other windows.

## Possible TV and Linux version

One idea for the future is to extend EasyLauncher with a TV interface for both Android TV and Linux. A shared core would serve both e-ink phones and a simple TV launcher for installed apps such as Kodi, ScummVM, or Steam Link.

The TV interface would use a landscape layout, clearly highlight the selected tile, and fully support a mouse, keyboard, and remote control. App launching and system integration would have separate implementations for Android and Linux. Another goal would be to make the Linux version a possible replacement for Flex Launcher.

Linux support and the TV interface are currently plans. Keeping the app lightweight and simple remains the priority, with memory and CPU usage also checked during everyday use.

## Building

The first build uses Flutter 3.47.9 with Dart 3.13.7, the Android SDK, and a JDK compatible with the bundled Gradle version. The minimum supported Android version is Android 7.0 (API 24).

```sh
flutter pub get
flutter analyze
flutter test
python3 tool/build_apk.py
```

The ARM64 APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Local builds use a development signing key; configure your own signing key in the Android project for distribution.

An optional personal profile is applied only on first launch. Subsequent updates preserve the settings saved on the phone.

```sh
python3 tool/build_apk.py --profile private/launcher-profile.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The profile is JSON with `schemaVersion: 1`, a `favorites` array, and optional `layout`, `actions`, `labels`, and `autoKeyboard` fields. Each app has a `packageName`, a fully qualified `activityName`, and a `label`. Actions use the `launchApp` type; supported keys are `clockTap`, `dateTap`, `swipeRight`, and `swipeLeft`. An empty profile starts with no favorites.

Keep personal profiles in the ignored `private/` directory. When used for a personal build, they become part of the APK; omit `--profile` when creating a public build.

## Device testing

```sh
flutter test integration_test/app_test.dart -d DEVICE_ID
```

The integration test checks native app discovery, saved settings, safe rejection of a nonexistent app, and search. It uses a separate development build with the application ID `one.jiri.easylauncher.debug`, keeping its settings separate from the normally installed app. Display quality and e-ink refresh behavior need to be assessed on the physical screen.

The release APK does not request access to the internet, contacts, calendar events, or the camera. It opens the corresponding apps through Android system interfaces.
