import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:easylauncher/main.dart';
import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:easylauncher/src/platform.dart';
import 'package:easylauncher/src/ui/home.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'support/fake_platform.dart';

void main() {
  setUpAll(() => initializeDateFormatting('cs_CZ'));

  Future<(LauncherController, FakePlatform)> launch(
    WidgetTester tester, {
    bool autoKeyboard = true,
    int extraApps = 0,
    int favoriteCount = 12,
  }) async {
    tester.view.physicalSize = const Size(824, 1648);
    tester.view.devicePixelRatio = 2.1;
    tester.view.padding = const FakeViewPadding(top: 49, bottom: 90);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final favorites = List.generate(
      favoriteCount,
      (i) => app('Favorite ${i + 1}'),
    );
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

  Finder favoriteTile(int number) =>
      find.byKey(ValueKey('favorite-test.favoritex$number'));

  Future<TestGesture> holdFavorite(WidgetTester tester, int number) async {
    final gesture = await tester.startGesture(
      tester.getCenter(favoriteTile(number)),
    );
    await tester.pump(kLongPressTimeout);
    return gesture;
  }

  Future<void> openFavoritesEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oblíbené aplikace'));
    await tester.pumpAndSettle();
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

  testWidgets('a label shrinks rather than split a word that can fit', (
    tester,
  ) async {
    Future<double?> size(double width) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              height: 80,
              child: const AdaptiveLabel(label: 'Fotoaparat', fontSize: 28),
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.text('Fotoaparat')).style!.fontSize;
    }

    expect(await size(150), 15);
    // Too narrow even at 12, so it is split at the largest size that fits two lines.
    expect(await size(100), 20);
  });

  testWidgets('dark mode turns the screens and the system bars black', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    Color? color(Finder text) =>
        tester.renderObject<RenderParagraph>(text).text.style?.color;

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    final toggle = find.text('Tmavý režim');
    await tester.scrollUntilVisible(toggle.hitTestable(), 200);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(LauncherSettings.decode(platform.saved!).darkMode, isTrue);
    expect(color(toggle), Colors.white);

    await tester.tap(find.byTooltip('Zpět'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Favorite 1'))).canvasColor,
      Colors.black,
    );
    expect(color(find.text('Favorite 1')), Colors.white);
    final bars = SystemChrome.latestStyle!;
    expect(bars.statusBarColor, Colors.black);
    expect(bars.statusBarIconBrightness, Brightness.light);
    expect(bars.systemNavigationBarColor, Colors.black);
    expect(bars.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('settings show the version reported by Android when available', (
    tester,
  ) async {
    const channel = MethodChannel('one.jiri.easylauncher/platform');
    const events = MethodChannel('one.jiri.easylauncher/events');
    final messenger = tester.binding.defaultBinaryMessenger;
    String? versionName = '7.8.9-debug';
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'getApps' => [],
        'getStatus' => {'versionName': versionName},
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(events, (_) async => null);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(events, null);
    });
    final controller = LauncherController(platform: AndroidLauncherPlatform());
    await tester.pumpWidget(EasyLauncherApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();

    final version = find.text('EasyLauncher $versionName');
    await tester.scrollUntilVisible(version, 200);
    expect(version, findsOneWidget);

    versionName = null;
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('EasyLauncher'), findsOneWidget);
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

  testWidgets('app icons load only when enabled and once per app', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester, autoKeyboard: false);
    platform.icon = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
    );
    final openApps = find.byKey(const ValueKey('open-apps'));
    Finder icon(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Image),
    );
    await tester.tap(openApps);
    await tester.pumpAndSettle();
    expect(platform.iconRequests, isEmpty);

    await controller.update(controller.settings.copyWith(showAppIcons: true));
    await tester.pumpAndSettle();
    expect(icon('app-test.kalendxx/test.MainActivity'), findsOneWidget);
    await tester.tap(find.byTooltip('Zpět'));
    await tester.pumpAndSettle();
    expect(icon('favorite-test.favoritex1'), findsOneWidget);
    final favoriteIcon = tester.getRect(icon('favorite-test.favoritex1'));
    final favoriteLabel = tester.getRect(find.text('Favorite 1'));
    expect(favoriteIcon.right, lessThan(favoriteLabel.left));
    expect(favoriteIcon.center.dy, closeTo(favoriteLabel.center.dy, 1));
    await controller.update(controller.settings.copyWith(columns: 3));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(icon('favorite-test.favoritex1')).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Favorite 1')).top),
    );

    final requests = [...platform.iconRequests];
    expect(requests.toSet(), hasLength(requests.length));
    await tester.tap(openApps);
    await tester.pump();
    expect(icon('app-test.kalendxx/test.MainActivity'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(platform.iconRequests, requests);

    platform.eventController.add('appsChanged');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(platform.iconRequests.length, greaterThan(requests.length));
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

  testWidgets('dragging a favorite previews its order and saves on release', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester);
    final favorites = controller.settings.favorites;
    final saves = platform.saves.length;
    final origin = tester.getCenter(favoriteTile(1));
    final destination = tester.getCenter(favoriteTile(6));

    final gesture = await holdFavorite(tester, 1);
    await gesture.moveTo(destination);
    await tester.pump();
    expect(tester.getCenter(favoriteTile(1)), destination);
    expect(tester.getCenter(favoriteTile(2)), origin);
    expect(controller.settings.favorites, favorites);
    expect(platform.saves, hasLength(saves));

    await gesture.up();
    await tester.pumpAndSettle();
    final expected = [...favorites];
    expected.insert(5, expected.removeAt(0));
    expect(controller.settings.favorites, expected);
    expect(platform.saves, hasLength(saves + 1));
    expect(
      LauncherSettings.decode(platform.saved!).favorites.map((app) => app.id),
      expected.map((app) => app.id),
    );
    expect(tester.getCenter(favoriteTile(1)), destination);
  });

  testWidgets('a held tile inverts and opens its menu on release', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester);
    await controller.update(controller.settings.copyWith(darkMode: true));
    await tester.pumpAndSettle();
    final saves = platform.saves.length;
    final origin = tester.getCenter(favoriteTile(1));

    final gesture = await holdFavorite(tester, 1);
    await gesture.moveBy(const Offset(3, 2));
    await tester.pump();
    final tile = tester.widget<Material>(
      find.ancestor(of: favoriteTile(1), matching: find.byType(Material)).first,
    );
    expect(tile.color, Colors.white);
    expect((tile.shape! as RoundedRectangleBorder).side.color, Colors.black);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Favorite 1'))
          .text
          .style
          ?.color,
      Colors.black,
    );
    expect(tester.getCenter(favoriteTile(1)), origin);
    expect(find.text('Přejmenovat'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Přejmenovat'), findsOneWidget);
    expect(platform.saves, hasLength(saves));
    expect(platform.calls, isEmpty);
  });

  testWidgets('the favorite tile menu offers remove, rename and app info', (
    tester,
  ) async {
    await launch(tester);
    await tester.longPress(favoriteTile(1));
    await tester.pumpAndSettle();

    expect(find.text('Změnit pořadí'), findsNothing);
    expect(find.text('Odebrat z oblíbených'), findsOneWidget);
    expect(find.text('Přejmenovat'), findsOneWidget);
    expect(find.text('Informace o aplikaci'), findsOneWidget);
  });

  testWidgets('moving a lifted tile does not trigger home swipes', (
    tester,
  ) async {
    final (_, platform) = await launch(tester);
    final across = tester.getCenter(favoriteTile(10));
    final above = tester.getCenter(favoriteTile(2));
    final gesture = await holdFavorite(tester, 9);
    await gesture.moveTo(across);
    await gesture.moveTo(above);
    await tester.pump();
    expect(tester.getCenter(favoriteTile(9)), above);
    expect(find.byKey(const ValueKey('app-search')), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-search')), findsNothing);
    expect(platform.calls, isEmpty);
  });

  testWidgets('dragging a tile away and back does not save or open a menu', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester);
    final favorites = controller.settings.favorites;
    final saves = platform.saves.length;
    final origin = tester.getCenter(favoriteTile(1));
    final destination = tester.getCenter(favoriteTile(5));

    final gesture = await holdFavorite(tester, 1);
    await gesture.moveTo(destination);
    await tester.pump();
    expect(tester.getCenter(favoriteTile(1)), destination);
    await gesture.moveTo(origin);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(favoriteTile(1)), origin);
    expect(controller.settings.favorites, favorites);
    expect(platform.saves, hasLength(saves));
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'a hold in a gap does nothing and an empty slot maps to the end',
    (tester) async {
      final (controller, platform) = await launch(tester, favoriteCount: 8);
      await controller.update(controller.settings.copyWith(columns: 3));
      await tester.pumpAndSettle();
      final saves = platform.saves.length;
      final first = tester.getRect(favoriteTile(1));
      final second = tester.getRect(favoriteTile(2));
      final gap = Offset((first.right + second.left) / 2, first.center.dy);
      final gapHold = await tester.startGesture(gap);
      await tester.pump(kLongPressTimeout);
      await gapHold.up();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(platform.saves, hasLength(saves));

      final last = tester.getCenter(favoriteTile(8));
      final empty = Offset(tester.getCenter(favoriteTile(3)).dx, last.dy);
      final gesture = await holdFavorite(tester, 1);
      await gesture.moveTo(empty);
      await tester.pump();
      expect(tester.getCenter(favoriteTile(1)), last);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.settings.favorites.last.label, 'Favorite 1');
    },
  );

  testWidgets('dragging to the grid edges scrolls to off-screen slots', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester, favoriteCount: 24);
    final favorites = controller.settings.favorites;
    final saves = platform.saves.length;
    final grid = find.byKey(const PageStorageKey('favorites'));
    final viewport = tester.getRect(grid);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: grid, matching: find.byType(Scrollable)),
    );
    final x = tester.getCenter(favoriteTile(2)).dx;
    final bottom = Offset(x, viewport.bottom - 4);
    expect(favoriteTile(24).hitTestable(), findsNothing);

    final gesture = await holdFavorite(tester, 1);
    await gesture.moveTo(bottom);
    await tester.pump(const Duration(seconds: 2));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(tester.getRect(favoriteTile(1)).bottom, closeTo(viewport.bottom, 1));

    await gesture.moveTo(Offset(x, viewport.top + 4));
    await tester.pump(const Duration(seconds: 2));
    expect(scrollable.position.pixels, 0);

    await gesture.moveTo(bottom);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.settings.favorites, favorites);
    expect(platform.saves, hasLength(saves));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.settings.favorites.last, favorites.first);
    expect(platform.saves, hasLength(saves + 1));
  });

  testWidgets('cancelling a drag stops edge scrolling and discards the move', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester, favoriteCount: 24);
    final favorites = controller.settings.favorites;
    final saves = platform.saves.length;
    final grid = find.byKey(const PageStorageKey('favorites'));
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: grid, matching: find.byType(Scrollable)),
        )
        .position;
    final gesture = await holdFavorite(tester, 1);
    await gesture.moveTo(
      Offset(
        tester.getCenter(favoriteTile(2)).dx,
        tester.getRect(grid).bottom - 4,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final scrolled = position.pixels;
    expect(scrolled, greaterThan(0));
    expect(scrolled, lessThan(position.maxScrollExtent));

    await gesture.cancel();
    await tester.pump(const Duration(seconds: 2));
    expect(position.pixels, scrolled);
    expect(controller.settings.favorites, favorites);
    expect(platform.saves, hasLength(saves));
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a change to favorites cancels the current drag', (tester) async {
    final (controller, platform) = await launch(tester);
    final favorites = controller.settings.favorites;
    final saves = platform.saves.length;
    final destination = tester.getCenter(favoriteTile(6));
    final gesture = await holdFavorite(tester, 1);
    await gesture.moveTo(destination);
    await tester.pump();
    expect(tester.getCenter(favoriteTile(1)), destination);

    await controller.removeFavorite(favorites.first);
    await tester.pump();
    expect(favoriteTile(1), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.settings.favorites, favorites.skip(1));
    expect(platform.saves, hasLength(saves + 1));
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'a hold opens the menu immediately when settings are unavailable',
    (tester) async {
      final (controller, platform) = await launch(tester);
      final favorites = controller.settings.favorites;
      final saves = platform.saves.length;
      platform.failLoad = true;
      await controller.reloadSettings();
      await tester.pumpAndSettle();
      expect(controller.settingsAvailable, isFalse);

      final origin = tester.getCenter(favoriteTile(1));
      final destination = tester.getCenter(favoriteTile(2));
      final gesture = await holdFavorite(tester, 1);
      expect(find.text('Přejmenovat'), findsOneWidget);
      await gesture.moveTo(destination);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(favoriteTile(1)), origin);
      expect(controller.settings.favorites, favorites);
      expect(platform.saves, hasLength(saves));
    },
  );

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

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  String shown(WidgetTester tester, String key) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('clock keeps time while a floating window covers home', (
    tester,
  ) async {
    await launch(tester);
    addTearDown(() => lifecycle(tester, AppLifecycleState.resumed));
    String current() => DateFormat('HH:mm').format(clock.now());
    final start = clock.now();
    // Mid-minute checks stay clear of the tick scheduled just after each minute.
    await tester.pump(
      Duration(milliseconds: 90000 - start.second * 1000 - start.millisecond),
    );

    await lifecycle(tester, AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 2));
    expect(shown(tester, 'clock'), current());

    final hiddenAt = shown(tester, 'clock');
    await lifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    // Paused home draws no frames, so force one to expose a tick that kept running.
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(shown(tester, 'clock'), hiddenAt);

    await lifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    expect(shown(tester, 'clock'), current());
    await tester.pump(const Duration(minutes: 1));
    expect(shown(tester, 'clock'), current());
  });

  final instant = DateTime.utc(2026, 11, 11, 23, 15, 10);
  testWidgets(
    'returning home shows a time zone change within the same minute',
    (tester) async {
      var now = instant.toLocal();
      await withClock(Clock(() => now), () async {
        await launch(tester);
        addTearDown(() => lifecycle(tester, AppLifecycleState.resumed));
        await lifecycle(tester, AppLifecycleState.paused);
        // The same instant in UTC stands in for a new local time zone.
        now = instant.add(const Duration(seconds: 20));
        await lifecycle(tester, AppLifecycleState.resumed);
        await tester.pump();
        expect(shown(tester, 'clock'), DateFormat('HH:mm').format(now));
        expect(
          shown(tester, 'date'),
          DateFormat('EEEE d. MMMM', 'cs_CZ').format(now),
        );
      });
    },
    skip: instant.toLocal().timeZoneOffset == Duration.zero,
  );

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

  testWidgets('dragging a favorite by its handle saves the new order', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester, favoriteCount: 3);
    final [first, second, third] = controller.settings.favorites;
    final saves = platform.saves.length;
    await openFavoritesEditor(tester);

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(3));
    final size = tester.getSize(handles.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    final origin = tester.getBottomLeft(handles.first) + const Offset(4, -4);
    final gesture = await tester.startGesture(origin);
    await gesture.moveTo(Offset(origin.dx, tester.getCenter(handles.last).dy));
    await tester.pump();

    final proxy = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(ValueKey(first.id)),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(proxy.elevation, 0);
    expect(
      proxy.shape,
      const RoundedRectangleBorder(side: BorderSide(width: 1.5)),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    final expected = [second, third, first];
    expect(controller.settings.favorites, expected);
    expect(platform.saves, hasLength(saves + 1));
    expect(
      LauncherSettings.decode(platform.saved!).favorites.map((app) => app.id),
      expected.map((app) => app.id),
    );
  });

  testWidgets('the favorites editor can remove the last favorite', (
    tester,
  ) async {
    final (controller, platform) = await launch(tester, favoriteCount: 1);
    await openFavoritesEditor(tester);
    await tester.tap(find.byTooltip('Odebrat z oblíbených'));
    await tester.pumpAndSettle();

    expect(controller.settings.favorites, isEmpty);
    expect(LauncherSettings.decode(platform.saved!).favorites, isEmpty);
    expect(find.text('Favorite 1'), findsNothing);
    expect(
      find.text('Aplikaci přidáš dlouhým podržením v seznamu aplikací.'),
      findsOneWidget,
    );
  });

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
