import 'dart:ui' show PointerDeviceKind;

import 'package:clock/clock.dart';
import 'package:easylauncher/main.dart';
import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:easylauncher/src/platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _TestLinuxPlatform extends LinuxLauncherPlatform {
  _TestLinuxPlatform(this.apps);

  final List<LaunchTarget>? apps;
  final launched = <String>[];

  @override
  Future<List<LaunchTarget>> getApps() async =>
      apps ?? (throw const FormatException());

  @override
  Future<String?> loadSettings() async => null;

  @override
  Future<void> saveSettings(String json) async {}

  @override
  Future<void> launchApp(LaunchTarget target) async =>
      launched.add(target.label);
}

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const linux = TargetPlatformVariant({TargetPlatform.linux});

  Future<_TestLinuxPlatform> launch(
    WidgetTester tester, {
    bool broken = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = _TestLinuxPlatform(
      broken
          ? null
          : [
              for (final name in [
                'Kodi',
                'ScummVM',
                'Steam Link',
                'Vypnout',
                'Restartovat',
              ])
                LaunchTarget.fromJson({
                  'label': name,
                  'command': name,
                }, linux: true),
            ],
    );
    await tester.pumpWidget(
      EasyLauncherApp(controller: LauncherController(platform: platform)),
    );
    await tester.pumpAndSettle();
    return platform;
  }

  testWidgets(
    'arrows move the visible focus and Enter and a mouse click launch tiles',
    (tester) async {
      final platform = await launch(tester);
      Color? color(String label) =>
          DefaultTextStyle.of(tester.element(find.text(label))).style.color;
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      expect(color('Kodi'), Colors.white);
      await press(LogicalKeyboardKey.arrowRight);
      expect(color('Kodi'), Colors.black);
      expect(color('ScummVM'), Colors.white);
      await press(LogicalKeyboardKey.arrowDown);
      expect(color('Restartovat'), Colors.white);
      await press(LogicalKeyboardKey.enter);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(color('Vypnout'), Colors.white);
      await press(LogicalKeyboardKey.arrowUp);
      expect(color('Kodi'), Colors.white);
      await tester.tap(find.text('Steam Link'), kind: PointerDeviceKind.mouse);
      expect(platform.launched, ['Restartovat', 'Steam Link']);
    },
    variant: linux,
  );

  testWidgets('an unreadable app list points to the configuration file', (
    tester,
  ) async {
    await launch(tester, broken: true);
    expect(find.textContaining('easylauncher/apps.json'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  }, variant: linux);

  testWidgets('TV home draws no frame while idle until the clock changes', (
    tester,
  ) async {
    final fakeTime = clock;
    final started = fakeTime.now();
    final noon = DateTime(2026, 11, 22, 12);
    await withClock(
      Clock(() => noon.add(fakeTime.now().difference(started))),
      () async {
        await launch(tester);
        expect(find.text('12:00'), findsOneWidget);
        var drewFrame = false;
        tester.binding.addPostFrameCallback((_) => drewFrame = true);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.pump(const Duration(seconds: 59));
        expect(drewFrame, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.pump(const Duration(seconds: 1, milliseconds: 100));
        expect(drewFrame, isTrue);
        expect(find.text('12:01'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }, variant: linux);
}
