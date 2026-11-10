import 'package:easylauncher/main.dart';
import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_platform.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<(LauncherController, FakePlatform)> launch(
    WidgetTester tester, {
    bool autoKeyboard = true,
    int extraApps = 0,
  }) async {
    tester.view.physicalSize = const Size(824, 1648);
    tester.view.devicePixelRatio = 2.1;
    tester.view.padding = const FakeViewPadding(top: 49, bottom: 90);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final favorites = List.generate(12, (i) => app('Favorite ${i + 1}'));
    final calendar = app('Kalendář');
    final platform = FakePlatform()
      ..apps = [
        ...favorites,
        calendar,
        app('Nastavení'),
        ...List.generate(
          extraApps,
          (i) => app('App ${i.toString().padLeft(2, '0')}'),
        ),
      ];
    final controller = LauncherController(
      platform: platform,
      initialProfile: LauncherSettings(
        favorites: favorites,
        autoKeyboard: autoKeyboard,
        actions: {LaunchAction.date: calendar},
      ).encode(),
    );
    await tester.pumpWidget(EasyLauncherApp(controller: controller));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await platform.eventController.close();
    });
    return (controller, platform);
  }

  testWidgets('twelve tiles fit in two columns at phone size and 180% text', (
    tester,
  ) async {
    await launch(tester);
    for (var i = 1; i <= 12; i++) {
      final tile = find.byKey(ValueKey('favorite-test.favoritex$i'));
      expect(tile, findsOneWidget);
      expect(
        tester.getRect(tile).bottom,
        lessThan(tester.getRect(find.byKey(const ValueKey('open-apps'))).top),
      );
    }
    final first = tester.getRect(
      find.byKey(const ValueKey('favorite-test.favoritex1')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('favorite-test.favoritex2')),
    );
    expect(first.top, second.top);
    expect(first.right, lessThan(second.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe up over a tile opens search and omits favorites', (
    tester,
  ) async {
    await launch(tester);
    await tester.drag(
      find.byKey(const ValueKey('favorite-test.favoritex7')),
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-search')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Favorite 1'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('app-search')),
      'kalendar',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kalendář'), findsOneWidget);
    expect(find.text('Nastavení'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upward drag opens apps before the finger is released', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('favorite-test.favoritex7'))),
    );
    await gesture.moveBy(const Offset(0, -24));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-search')), findsOneWidget);
    await gesture.moveBy(const Offset(0, 140));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-search')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(platform.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short slow upward drag keeps favorites open', (tester) async {
    final (_, platform) = await launch(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('favorite-test.favoritex7'))),
    );
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, -15));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-search')), findsNothing);
    expect(platform.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite tiles expose tap and long press to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    final data = tester
        .getSemantics(find.bySemanticsLabel('Favorite 1'))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    semantics.dispose();
  });

  testWidgets('horizontal swipes on tiles choose camera and contacts', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    final tile = find.byKey(const ValueKey('favorite-test.favoritex7'));
    await tester.drag(tile, const Offset(130, 0));
    await tester.pumpAndSettle();
    await tester.drag(tile, const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(platform.calls, ['openContacts', 'openCamera']);
  });

  testWidgets('clock, date and swipe down call their designated actions', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('clock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('date')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('favorite-test.favoritex3')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(platform.calls, [
      'openAlarms',
      app('Kalendář').packageName,
      'notifications',
    ]);
  });

  testWidgets('HOME event closes search and dismisses keyboard', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    platform.eventController.add('home');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-search')), findsNothing);
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('native resume event refreshes the application list', (
    tester,
  ) async {
    final (_, platform) = await launch(tester, autoKeyboard: false);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    final installed = app('Časovač');
    platform.apps = [...platform.apps, installed];
    platform.eventController.add('resume');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('app-search')), 'casovac');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('app-${installed.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic keyboard can be disabled', (tester) async {
    await launch(tester, autoKeyboard: false);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('pulling down the app list closes it and the keyboard', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Kalendář'), const Offset(0, 130));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-search')), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(platform.calls, isEmpty);
  });

  testWidgets('pulling down an empty search returns to favorites', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('app-search')),
      'no-such-app',
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.text('Žádná aplikace neodpovídá hledání.'),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'a scrolled list scrolls back normally and its header dismisses it',
    (tester) async {
      await launch(tester, autoKeyboard: false, extraApps: 40);
      await tester.tap(find.byKey(const ValueKey('open-apps')));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('app-list'));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      final position = scrollable.position.pixels;
      expect(position, greaterThan(300));
      await tester.drag(list, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, lessThan(position));
      expect(find.byKey(const ValueKey('app-search')), findsOneWidget);
      await tester.drag(find.text('Aplikace'), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    },
  );

  testWidgets(
    'selected column numbers have contrasting text in both selections',
    (tester) async {
      final (controller, _) = await launch(tester);
      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(SegmentedButton<int>),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      Color? color(String text) =>
          DefaultTextStyle.of(tester.element(find.text(text))).style.color;
      expect(color('2'), Colors.white);
      expect(color('3'), Colors.black);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(controller.settings.columns, 3);
      expect(color('3'), Colors.white);
      expect(color('2'), Colors.black);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Enter keeps rename open and an explicit line break persists', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester);
    await tester.longPress(
      find.byKey(const ValueKey('favorite-test.favoritex1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přejmenovat'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(
      tester.widget<TextField>(field).textInputAction,
      TextInputAction.newline,
    );
    expect(
      tester.widget<TextField>(field).keyboardType,
      TextInputType.multiline,
    );
    await tester.enterText(field, 'Antenna\nPod');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Uložit'));
    await tester.pumpAndSettle();
    expect(controller.settings.favorites.first.label, 'Antenna\nPod');
    expect(
      LauncherSettings.decode(platform.saved!).favorites.first.label,
      'Antenna\nPod',
    );
    expect(find.text('Antenna\nPod'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three explicitly entered name lines fit inside a favorite tile',
    (tester) async {
      final (controller, _) = await launch(tester);
      const name = 'Anténa\nPod\ncasty';
      await controller.rename(controller.settings.favorites.first, name);
      await tester.pumpAndSettle();
      final text = find.text(name);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getRect(text).height,
        lessThanOrEqualTo(
          tester
                  .getRect(
                    find.byKey(const ValueKey('favorite-test.favoritex1')),
                  )
                  .height -
              16,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual multiline glyphs stay inside tiles with thirteen favorites',
    (tester) async {
      final (controller, _) = await launch(tester);
      await controller.addFavorite(
        controller.apps.firstWhere((app) => app.label == 'Kalendář'),
      );
      for (final name in ['Moje\nonline\nrádio\nPlus', 'A\nB\nC\nD\nE\nF']) {
        await controller.rename(controller.settings.favorites.first, name);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: name.length),
        );
        expect(boxes, isNotEmpty);
        expect(paragraph.didExceedMaxLines, isFalse);
        for (final box in boxes) {
          expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('long press adds an app and removes it from the drawer', (
    tester,
  ) async {
    final (controller, _) = await launch(tester, autoKeyboard: false);
    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Kalendář'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Přidat k oblíbeným'));
    await tester.pumpAndSettle();
    expect(controller.settings.favorites, hasLength(13));
    expect(find.text('Kalendář'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
