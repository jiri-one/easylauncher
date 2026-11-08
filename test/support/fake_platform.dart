import 'dart:async';

import 'package:easylauncher/src/models.dart';
import 'package:easylauncher/src/platform.dart';

LaunchTarget app(String name, {String? package, String? activity}) =>
    LaunchTarget(
      label: name,
      packageName:
          package ??
          'test.${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), 'x')}',
      activityName: activity ?? 'test.MainActivity',
    );

class FakePlatform implements LauncherPlatform {
  List<LaunchTarget> apps = [];
  String? saved;
  bool failSave = false;
  bool failLoad = false;
  bool notifications = true;
  final calls = <String>[];
  final saves = <String>[];
  final eventController = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get events => eventController.stream;

  @override
  Future<List<LaunchTarget>> getApps() async => apps;

  @override
  Future<String?> loadSettings() async {
    if (failLoad) throw StateError('Read failed');
    return saved;
  }

  @override
  Future<void> saveSettings(String json) async {
    if (failSave) throw StateError('Disk full');
    saved = json;
    saves.add(json);
  }

  @override
  Future<void> launchApp(LaunchTarget app) async => calls.add(app.packageName);

  @override
  Future<void> openAction(LaunchAction action) async =>
      calls.add(action.method);

  @override
  Future<bool> openNotifications() async {
    calls.add('notifications');
    return notifications;
  }

  @override
  Future<LauncherStatus> getStatus() async => const LauncherStatus();

  @override
  Future<void> requestDefaultLauncher() async => calls.add('default');

  @override
  Future<void> openAccessibilitySettings() async => calls.add('accessibility');

  @override
  Future<void> openAppDetails(String packageName) async => calls.add('details');
}
