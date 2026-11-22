import 'dart:io';

import 'package:easylauncher/src/models.dart';
import 'package:easylauncher/src/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory config;
  late LinuxLauncherPlatform platform;
  late File appsFile;

  setUp(() async {
    config = await Directory.systemTemp.createTemp('easylauncher-test-');
    addTearDown(() => config.delete(recursive: true));
    platform = LinuxLauncherPlatform(configDirectory: config);
    appsFile = File('${config.path}/apps.json');
  });

  test('reads the favorites in profile order', () async {
    await appsFile.writeAsString('''
      {"schemaVersion": 1, "favorites": [
        {"label": "Kodi", "command": "kodi", "icon": "/icons/kodi.png"},
        {"label": "Vypnout", "command": "systemctl poweroff"}
      ]}
    ''');
    final apps = await platform.getApps();
    expect(apps.map((app) => app.label), ['Kodi', 'Vypnout']);
    expect(apps.map((app) => app.command), ['kodi', 'systemctl poweroff']);
    expect(apps.map((app) => app.icon), ['/icons/kodi.png', null]);
  });

  test('reports missing, malformed and invalid app lists', () async {
    await expectLater(platform.getApps(), throwsA(isA<FileSystemException>()));
    await appsFile.writeAsString('{');
    await expectLater(platform.getApps(), throwsFormatException);
    await appsFile.writeAsString('''
      {"schemaVersion": 1, "favorites": [{"label": "Kodi", "command": " "}]}
    ''');
    await expectLater(platform.getApps(), throwsFormatException);
  });

  test('runs the whole command in a shell', () async {
    final made = Directory('${config.path}/My Games');
    await platform.launchApp(
      LaunchTarget.fromJson({
        'label': 'ScummVM',
        'command': 'mkdir "${made.path}"',
      }),
    );
    while (!await made.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
}
