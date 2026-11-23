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

  test('rejects a missing command before launching', () async {
    for (final command in [
      'easylauncher-missing-command',
      '${config.path}/missing=command --option',
      '"${config.path}/missing command" --option',
    ]) {
      await expectLater(
        platform.launchApp(
          LaunchTarget.fromJson({'label': 'Missing', 'command': command}),
        ),
        throwsA(isA<ProcessException>()),
      );
    }
  });

  test('leaves no zombie process behind', () async {
    await platform.launchApp(
      LaunchTarget.fromJson({'label': 'Sleep', 'command': 'sleep 1'}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Reads /proc directly: starting ps would make Dart reap its children.
    final zombies = Directory('/proc').listSync().where((entry) {
      try {
        final fields = File('${entry.path}/stat')
            .readAsStringSync()
            .split(') ')
            .last
            .split(' ');
        return fields[0] == 'Z' && fields[1] == '$pid';
      } on FileSystemException {
        return false;
      }
    });
    expect(zombies, isEmpty);
  });

  for (final (label, command) in [
    ('a command name', 'mkdir'),
    ('an absolute path', r"""'/bin/sh' -c 'mkdir "$1"' sh"""),
    ('an environment assignment', 'EASYLAUNCHER_TEST=1 mkdir'),
  ]) {
    test('runs $label with arguments in a shell', () async {
      final made = Directory('${config.path}/My Games');
      final created = config
          .watch(events: FileSystemEvent.create)
          .firstWhere((event) => event.path == made.path);
      await platform.launchApp(
        LaunchTarget.fromJson({
          'label': 'Create directory',
          'command': '$command "${made.path}"',
        }),
      );
      await created;
      expect(await made.exists(), isTrue);
    });
  }
}
