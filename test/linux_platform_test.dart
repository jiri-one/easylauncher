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
        {"label": "Kodi", "command": "kodi"},
        {"label": "Vypnout", "command": "systemctl poweroff"}
      ]}
    ''');
    final apps = await platform.getApps();
    expect(apps.map((app) => app.label), ['Kodi', 'Vypnout']);
    expect(apps.map((app) => app.command), ['kodi', 'systemctl poweroff']);
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

  test('saves and replaces settings with their commands', () async {
    expect(await platform.loadSettings(), isNull);
    final settings = LauncherSettings(
      favorites: [
        LaunchTarget.fromJson({'label': 'Kodi', 'command': 'kodi'}),
      ],
    );
    await platform.saveSettings(settings.encode());
    final saved = LauncherSettings.decode((await platform.loadSettings())!);
    expect(saved.favorites.single.command, 'kodi');
    final updated = settings.copyWith(columns: 3).encode();
    await platform.saveSettings(updated);
    expect(await platform.loadSettings(), updated);
    expect(
      await config.list().map((entry) => entry.uri.pathSegments.last).toList(),
      ['settings.json'],
    );
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
