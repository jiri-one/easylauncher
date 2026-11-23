import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

class LauncherStatus {
  const LauncherStatus({
    this.isDefault = false,
    this.notificationsEnabled = false,
    this.versionName,
  });
  final bool isDefault;
  final bool notificationsEnabled;
  final String? versionName;
}

abstract class LauncherPlatform {
  Stream<String> get events;
  Future<List<LaunchTarget>> getApps();
  Future<Uint8List?> getAppIcon(LaunchTarget app);
  Future<String?> loadSettings();
  Future<void> saveSettings(String json);
  Future<void> launchApp(LaunchTarget app);
  Future<void> openAction(LaunchAction action);
  Future<bool> openNotifications();
  Future<LauncherStatus> getStatus();
  Future<void> requestDefaultLauncher();
  Future<void> openAccessibilitySettings();
  Future<void> openAppDetails(String packageName);
}

class AndroidLauncherPlatform implements LauncherPlatform {
  static const _methods = MethodChannel('one.jiri.easylauncher/platform');
  static const _events = EventChannel('one.jiri.easylauncher/events');

  late final Stream<String> _eventStream = _events.receiveBroadcastStream().map(
    (event) => (event as Map)['type'] as String,
  );

  @override
  Stream<String> get events => _eventStream;

  @override
  Future<List<LaunchTarget>> getApps() async {
    final apps = await _methods.invokeListMethod<dynamic>('getApps') ?? [];
    return apps
        .map(
          (entry) =>
              LaunchTarget.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  @override
  Future<Uint8List?> getAppIcon(LaunchTarget app) =>
      _methods.invokeMethod<Uint8List>('getAppIcon', app.toJson());

  @override
  Future<String?> loadSettings() =>
      _methods.invokeMethod<String>('loadSettings');

  @override
  Future<void> saveSettings(String json) =>
      _methods.invokeMethod<void>('saveSettings', {'json': json});

  @override
  Future<void> launchApp(LaunchTarget app) =>
      _methods.invokeMethod<void>('launchApp', app.toJson());

  @override
  Future<void> openAction(LaunchAction action) =>
      _methods.invokeMethod<void>(action.method);

  @override
  Future<bool> openNotifications() async =>
      await _methods.invokeMethod<bool>('openNotifications') ?? false;

  @override
  Future<LauncherStatus> getStatus() async {
    final status = await _methods.invokeMapMethod<String, dynamic>('getStatus');
    return LauncherStatus(
      isDefault: status?['isDefaultLauncher'] == true,
      notificationsEnabled: status?['isAccessibilityEnabled'] == true,
      versionName: status?['versionName'] as String?,
    );
  }

  @override
  Future<void> requestDefaultLauncher() =>
      _methods.invokeMethod<void>('requestDefaultLauncher');

  @override
  Future<void> openAccessibilitySettings() =>
      _methods.invokeMethod<void>('openAccessibilitySettings');

  @override
  Future<void> openAppDetails(String packageName) => _methods
      .invokeMethod<void>('openAppDetails', {'packageName': packageName});
}

class LinuxLauncherPlatform implements LauncherPlatform {
  LinuxLauncherPlatform({Directory? configDirectory})
    : _configDirectory = configDirectory ?? _defaultDirectory();

  final Directory _configDirectory;

  static Directory _defaultDirectory() {
    final env = Platform.environment;
    final xdg = env['XDG_CONFIG_HOME'] ?? '';
    return Directory(
      '${xdg.isEmpty ? '${env['HOME']}/.config' : xdg}/easylauncher',
    );
  }

  @override
  Stream<String> get events => const Stream.empty();

  @override
  Future<List<LaunchTarget>> getApps() async => LauncherSettings.decode(
    await File('${_configDirectory.path}/apps.json').readAsString(),
  ).favorites;

  @override
  Future<Uint8List?> getAppIcon(LaunchTarget app) async => null;

  // Nothing on the TV home changes settings yet.
  @override
  Future<String?> loadSettings() async => null;

  @override
  Future<void> saveSettings(String json) async {}

  // A detached start would leave a zombie per launch until the launcher exits.
  @override
  Future<void> launchApp(LaunchTarget app) => Process.run('/bin/sh', [
    '-c',
    r'eval "$1" </dev/null >/dev/null 2>&1 &',
    'sh',
    app.command!,
  ]);

  @override
  Future<void> openAction(LaunchAction action) async {}

  @override
  Future<bool> openNotifications() async => false;

  @override
  Future<LauncherStatus> getStatus() async => const LauncherStatus();

  @override
  Future<void> requestDefaultLauncher() async {}

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openAppDetails(String packageName) async {}
}
