import 'dart:ui' show PointerDeviceKind;

import 'package:clock/clock.dart';
import 'package:easylauncher/main.dart';
import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_platform.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const linux = TargetPlatformVariant({TargetPlatform.linux});

  Future<FakePlatform> launch(WidgetTester tester, {bool empty = false}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakePlatform();
    if (!empty) {
      platform.apps = [
        for (final name in [
          'Kodi',
          'ScummVM',
          'Steam Link',
          'Vypnout',
          'Restartovat',
        ])
          LaunchTarget.fromJson({'label': name, 'command': name}),
      ];
    }
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
          tester.widget<Text>(find.text(label)).style?.color;
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
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Steam Link'), kind: PointerDeviceKind.mouse);
      expect(platform.calls, ['Restartovat', 'Steam Link']);
    },
    variant: linux,
  );

  testWidgets('arrows continue from the tile highlighted by mouse hover', (
    tester,
  ) async {
    final platform = await launch(tester);
    Color? color(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(2, 2));
    addTearDown(mouse.removePointer);
    final tile = tester.getRect(
      find.widgetWithText(FocusableActionDetector, 'ScummVM'),
    );
    await mouse.moveTo(tile.centerLeft + const Offset(4, 0));
    await tester.pump();
    expect(color('Kodi'), Colors.black);
    expect(color('ScummVM'), Colors.white);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(color('ScummVM'), Colors.black);
    expect(color('Steam Link'), Colors.white);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(platform.calls, isEmpty);
  }, variant: linux);

  testWidgets('a held or repeated Enter starts an app only once', (
    tester,
  ) async {
    final platform = await launch(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(platform.calls, ['Kodi']);
    await tester.pump(const Duration(seconds: 3));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(platform.calls, ['Kodi', 'Kodi']);
  }, variant: linux);

  testWidgets('tiles keep their size on a 4K screen without output scaling', (
    tester,
  ) async {
    await launch(tester);
    final hd = tester.getRect(find.byType(FocusableActionDetector).first);
    tester.view.physicalSize = const Size(3840, 2160);
    await tester.pumpAndSettle();
    final uhd = tester.getRect(find.byType(FocusableActionDetector).first);
    expect(uhd.height, moreOrLessEquals(hd.height * 3));
    expect(uhd.width, moreOrLessEquals(hd.width * 3));
  }, variant: linux);

  testWidgets('an empty app list points to the configuration file', (
    tester,
  ) async {
    await launch(tester, empty: true);
    expect(find.textContaining('easylauncher/apps.json'), findsOneWidget);
    expect(find.byType(FocusableActionDetector), findsNothing);
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
