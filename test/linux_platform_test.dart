import 'dart:io';

import 'package:easylauncher/src/models.dart';
import 'package:easylauncher/src/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory config;
  late LinuxLauncherPlatform platform;
  late File appsFile;

  setUp(() async {
    final work = await Directory('.ai').create(recursive: true);
    config = await work.createTemp('linux-platform-test-');
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

  test('saves and replaces settings independently of the app list', () async {
    expect(await platform.loadSettings(), isNull);
    final app = LaunchTarget.fromJson({
      'label': 'Kodi',
      'command': 'kodi',
    }, linux: true);
    final settings = LauncherSettings(favorites: [app]);
    await platform.saveSettings(settings.encode());
    final reader = LinuxLauncherPlatform(configDirectory: config);
    expect(await reader.loadSettings(), settings.encode());
    final saved = LauncherSettings.decode(
      await reader.loadSettings() ?? '',
      linux: true,
    );
    expect(saved.favorites.single.command, 'kodi');
    final updated = settings.copyWith(columns: 3).encode();
    await platform.saveSettings(updated);
    expect(await reader.loadSettings(), updated);
    expect(await appsFile.exists(), isFalse);
    expect(
      await config.list().map((entry) => entry.uri.pathSegments.last).toList(),
      ['settings.json'],
    );
  });

  test('passes the whole command to a detached shell', () async {
    const command = 'scummvm --path="/media/My Games" monkey';
    final calls = <Object>[];
    final launcher = LinuxLauncherPlatform(
      configDirectory: config,
      startProcess: (executable, arguments, {required mode}) async {
        calls.addAll([executable, arguments, mode]);
      },
    );
    final app = LaunchTarget.fromJson({
      'label': 'ScummVM',
      'command': command,
    }, linux: true);
    await launcher.launchApp(app);
    expect(calls, [
      '/bin/sh',
      ['-c', command],
      ProcessStartMode.detached,
    ]);
  });
}
