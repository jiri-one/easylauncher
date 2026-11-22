import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:clock/clock.dart';
import 'package:easylauncher/main.dart';
import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_platform.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  const linux = TargetPlatformVariant({TargetPlatform.linux});

  Future<FakePlatform> launch(
    WidgetTester tester, {
    Map<String, String> icons = const {},
    List<String> names = const [
      'Kodi',
      'ScummVM',
      'Steam Link',
      'Vypnout',
      'Restartovat',
    ],
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakePlatform();
    platform.apps = [
      for (final name in names)
        LaunchTarget.fromJson({
          'label': name,
          'command': name,
          'icon': icons[name],
        }),
    ];
    await tester.pumpWidget(
      EasyLauncherApp(controller: LauncherController(platform: platform)),
    );
    await tester.pumpAndSettle();
    return platform;
  }

  File writeIcon() {
    final directory = Directory.systemTemp.createTempSync('easylauncher-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    return File('${directory.path}/icon.png')..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
      ),
    );
  }

  Finder tile(String label) =>
      find.widgetWithText(FocusableActionDetector, label);

  testWidgets(
    'arrows move the visible focus and Enter and a mouse click launch tiles',
    (tester) async {
      final platform = await launch(tester);
      Color? color(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((tile) => tile.decoration! as BoxDecoration);
      expect(boxes.map((box) => box.color), [
        Colors.white,
        ...List.filled(4, Colors.black),
      ]);
      expect(
        boxes.map((box) => box.border),
        everyElement(Border.all(color: Colors.white, width: 2)),
      );
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      expect(color('Kodi'), Colors.black);
      await press(LogicalKeyboardKey.arrowRight);
      expect(color('Kodi'), Colors.white);
      expect(color('ScummVM'), Colors.black);
      await press(LogicalKeyboardKey.arrowDown);
      expect(color('Restartovat'), Colors.black);
      await press(LogicalKeyboardKey.enter);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(color('Vypnout'), Colors.black);
      await press(LogicalKeyboardKey.arrowUp);
      expect(color('Kodi'), Colors.black);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Steam Link'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(platform.calls, ['Restartovat', 'Steam Link']);
      expect(color('Steam Link'), Colors.black);
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
    final bounds = tester.getRect(tile('ScummVM'));
    await mouse.moveTo(bounds.centerLeft + const Offset(4, 0));
    await tester.pump();
    expect(color('Kodi'), Colors.white);
    expect(color('ScummVM'), Colors.black);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(color('ScummVM'), Colors.white);
    expect(color('Steam Link'), Colors.black);
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
    await launch(tester, names: const []);
    expect(find.textContaining('easylauncher/apps.json'), findsOneWidget);
    expect(find.byType(FocusableActionDetector), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.black,
    );
    expect(
      tester.widgetList<ColoredBox>(find.byType(ColoredBox)).first.color,
      Colors.black,
    );
    for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
      expect(text.text.style?.color, Colors.white);
    }
  }, variant: linux);

  testWidgets('tiles show existing icons above labels and hide missing icons', (
    tester,
  ) async {
    final icon = writeIcon();
    // Files load only in real time, which the fake test clock never reaches.
    await tester.runAsync(() async {
      await launch(
        tester,
        icons: {'Kodi': icon.path, 'ScummVM': '${icon.path}.missing'},
      );
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage(
          (element.widget as Image).image,
          element,
          onError: (_, _) {},
        );
      }
    });
    await tester.pump();
    final image = find.byType(RawImage);
    expect(tester.widget<RawImage>(image).image, isNotNull);
    expect(find.descendant(of: tile('Kodi'), matching: image), findsOneWidget);
    expect(
      tester.getBottomLeft(image).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Kodi')).dy),
    );
  }, variant: linux);

  testWidgets('a long label under an icon is cut to one line, not clipped', (
    tester,
  ) async {
    const long = 'Vypnout počítač hned teď';
    final icon = writeIcon();
    await tester.runAsync(() async {
      await launch(tester, names: [long], icons: {long: icon.path});
      final element = find.byType(Image).evaluate().single;
      await precacheImage((element.widget as Image).image, element);
    });
    await tester.pump();
    final label = tester.renderObject<RenderParagraph>(find.text(long));
    expect(
      label.getMaxIntrinsicHeight(label.size.width),
      lessThanOrEqualTo(label.size.height),
    );
  }, variant: linux);

  testWidgets('TV home draws no frame while idle until the clock changes', (
    tester,
  ) async {
    final icon = writeIcon();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () =>
          precacheImage(FileImage(icon), tester.element(find.byType(SizedBox))),
    );
    final fakeTime = clock;
    final started = fakeTime.now();
    final noon = DateTime(2026, 11, 22, 12);
    await withClock(
      Clock(() => noon.add(fakeTime.now().difference(started))),
      () async {
        await launch(tester, icons: {'Kodi': icon.path});
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
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
