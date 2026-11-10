import 'dart:convert';

import 'package:easylauncher/src/controller.dart';
import 'package:easylauncher/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform.dart';

void main() {
  late FakePlatform platform;
  late LauncherController controller;
  final browser = app('Browser');
  final calendar = app('Calendar');
  final phone = app('Phone');

  setUp(() {
    platform = FakePlatform()..apps = [phone, calendar, browser];
    controller = LauncherController(
      platform: platform,
      initialProfile: LauncherSettings(
        favorites: [browser],
        actions: {LaunchAction.date: calendar},
      ).encode(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await platform.eventController.close();
  });

  test(
    'personal profile is seeded once and saved changes win on restart',
    () async {
      await controller.initialize();
      expect(controller.settings.favorites.single.id, browser.id);
      await controller.addFavorite(phone);
      final restart = LauncherController(
        platform: platform,
        initialProfile: LauncherSettings().encode(),
      );
      await restart.initialize();
      expect(restart.settings.favorites.map((app) => app.id), [
        browser.id,
        phone.id,
      ]);
      restart.dispose();
    },
  );

  test(
    'favorites are absent from the drawer, including search results',
    () async {
      await controller.initialize();
      expect(controller.visibleApps().map((app) => app.id), [
        calendar.id,
        phone.id,
      ]);
      expect(controller.visibleApps(query: 'Browser'), isEmpty);
      expect(
        controller
            .visibleApps(query: 'Browser', includeFavorites: true)
            .single
            .id,
        browser.id,
      );
    },
  );

  test('date uses selected calendar without adding it to favorites', () async {
    await controller.initialize();
    await controller.perform(LaunchAction.date);
    expect(platform.calls, [calendar.packageName]);
    expect(controller.isFavorite(calendar), isFalse);
  });

  test(
    'rename, order and removal persist as one ordered configuration',
    () async {
      await controller.initialize();
      await controller.addFavorite(phone);
      await controller.rename(phone, 'Volání');
      await controller.moveFavorite(1, 0);
      expect(controller.settings.favorites.map((app) => app.label), [
        'Volání',
        'Browser',
      ]);
      await controller.removeFavorite(browser);
      final saved = LauncherSettings.decode(platform.saved!);
      expect(saved.favorites.single.label, 'Volání');
      expect(
        controller.visibleApps().any((app) => app.id == browser.id),
        isTrue,
      );
    },
  );

  test('search accepts Czech without accents and finds custom names', () async {
    final timer = app('Časovač');
    platform.apps = [timer];
    await controller.initialize();
    expect(controller.visibleApps(query: 'casovac').single.id, timer.id);
    await controller.rename(timer, 'Minutka');
    expect(controller.visibleApps(query: 'minutka').single.id, timer.id);
    expect(controller.visibleApps(query: 'časovač').single.id, timer.id);
  });

  test('drawer order and search follow renames and favorite changes', () async {
    await controller.initialize();
    expect(controller.visibleApps().map((app) => app.id), [
      calendar.id,
      phone.id,
    ]);
    await controller.rename(phone, 'Časovač');
    expect(controller.visibleApps().map((app) => app.id), [
      calendar.id,
      phone.id,
    ]);
    await controller.rename(phone, 'Budík');
    expect(controller.visibleApps().map((app) => app.id), [
      phone.id,
      calendar.id,
    ]);
    expect(controller.visibleApps(query: 'casovac'), isEmpty);
    expect(controller.visibleApps(query: 'budik').single.id, phone.id);
    expect(controller.visibleApps(query: 'phone').single.id, phone.id);
    await controller.addFavorite(phone);
    expect(controller.visibleApps(query: 'budik'), isEmpty);
    expect(
      controller.visibleApps(query: 'budik', includeFavorites: true).single.id,
      phone.id,
    );
    await controller.removeFavorite(phone);
    expect(controller.visibleApps(query: 'budik').single.id, phone.id);
  });

  test('drawer reflects reloaded settings and installed app changes', () async {
    await controller.initialize();
    controller.visibleApps(includeFavorites: true);
    platform.saved = LauncherSettings(
      favorites: [phone],
      labels: {calendar.id: 'Diář'},
    ).encode();
    await controller.reloadSettings();
    expect(controller.visibleApps().map((app) => app.id), [
      browser.id,
      calendar.id,
    ]);
    expect(controller.visibleApps(query: 'diar').single.id, calendar.id);
    final timer = app('Časovač');
    platform.apps = [phone, timer];
    await controller.refresh();
    expect(controller.visibleApps().map((app) => app.id), [timer.id]);
    expect(controller.visibleApps(query: 'diar'), isEmpty);
    expect(controller.visibleApps(query: 'casovac').single.id, timer.id);
    expect(
      controller.visibleApps(includeFavorites: true).map((app) => app.id),
      [timer.id, phone.id],
    );
  });

  test('equally named apps keep deterministic component order', () async {
    final second = app('Hodiny', package: 'test.second');
    final first = app('Hodiny', package: 'test.first');
    platform.apps = [second, first];
    await controller.initialize();
    expect(controller.visibleApps().map((app) => app.id), [
      first.id,
      second.id,
    ]);
    expect(controller.visibleApps(query: 'hodiny').map((app) => app.id), [
      first.id,
      second.id,
    ]);
  });

  test(
    'changed launcher alias resolves by unique package and stays excluded',
    () async {
      final updated = app(
        'Browser',
        package: browser.packageName,
        activity: 'test.NewAlias',
      );
      platform.apps = [updated, calendar];
      await controller.initialize();
      expect(controller.visibleApps().map((app) => app.id), [calendar.id]);
      await controller.launch(controller.settings.favorites.single);
      expect(platform.calls.single, browser.packageName);
      await controller.addFavorite(updated);
      expect(controller.settings.favorites, hasLength(1));
    },
  );

  test('uninstalled favorite is retained for later reinstallation', () async {
    await controller.initialize();
    platform.apps = [calendar];
    await controller.refresh();
    expect(controller.settings.favorites.single.id, browser.id);
    expect(controller.resolve(browser), isNull);
  });

  test('failed saves are visible and do not poison subsequent saves', () async {
    await controller.initialize();
    platform.failSave = true;
    await controller.addFavorite(phone);
    expect(controller.error, isNotNull);
    platform.failSave = false;
    await controller.update(controller.settings.copyWith(columns: 3));
    expect(LauncherSettings.decode(platform.saved!).columns, 3);
  });

  test('corrupt saved settings are not overwritten during startup', () async {
    platform.saved = '{bad json';
    await controller.initialize();
    expect(controller.ready, isTrue);
    expect(controller.error, isNotNull);
    expect(platform.saved, '{bad json');
    expect(platform.saves, isEmpty);
  });

  test('failed settings load locks edits until a successful reload', () async {
    final original = LauncherSettings(favorites: [phone]).encode();
    platform.saved = original;
    platform.failLoad = true;
    await controller.initialize();
    expect(controller.settingsAvailable, isFalse);
    await controller.update(controller.settings.copyWith(autoKeyboard: false));
    expect(platform.saved, original);
    expect(platform.saves, isEmpty);
    platform.failLoad = false;
    await controller.reloadSettings();
    expect(controller.settingsAvailable, isTrue);
    expect(controller.settings.favorites.single.id, phone.id);
    await controller.update(controller.settings.copyWith(autoKeyboard: false));
    expect(
      LauncherSettings.decode(platform.saved!).favorites.single.id,
      phone.id,
    );
  });

  test(
    'renamed drawer apps retain their labels after alias replacement',
    () async {
      await controller.initialize();
      await controller.rename(calendar, 'Plán');
      final changed = app(
        'Calendar',
        package: calendar.packageName,
        activity: 'test.NewCalendar',
      );
      platform.apps = [browser, phone, changed];
      await controller.refresh();
      expect(controller.label(changed), 'Plán');
      expect(controller.visibleApps(query: 'plan').single.id, changed.id);
      expect(controller.visibleApps(query: 'calendar').single.id, changed.id);
      expect(
        LauncherSettings.decode(platform.saved!).labels[changed.id],
        'Plán',
      );
    },
  );

  test('migrated favorite names survive removal from favorites', () async {
    await controller.initialize();
    await controller.rename(browser, 'Web');
    final changed = app(
      'Browser',
      package: browser.packageName,
      activity: 'test.NewBrowser',
    );
    platform.apps = [changed, calendar, phone];
    await controller.refresh();
    final favorite = controller.settings.favorites.single;
    expect(favorite.id, changed.id);
    await controller.removeFavorite(browser);
    expect(controller.label(changed), 'Web');
    expect(LauncherSettings.decode(platform.saved!).labels[changed.id], 'Web');
  });

  test('queued updates persist the most recent selection', () async {
    await controller.initialize();
    final first = controller.update(controller.settings.copyWith(columns: 3));
    final second = controller.update(
      controller.settings.copyWith(autoKeyboard: false),
    );
    await Future.wait([first, second]);
    final saved = LauncherSettings.decode(platform.saved!);
    expect(saved.columns, 3);
    expect(saved.autoKeyboard, isFalse);
  });

  test('profile parser rejects incompatible versions and invalid layout', () {
    final json =
        jsonDecode(LauncherSettings().encode()) as Map<String, dynamic>;
    json['schemaVersion'] = 2;
    expect(
      () => LauncherSettings.decode(jsonEncode(json)),
      throwsFormatException,
    );
    json['schemaVersion'] = 1;
    json['layout'] = {'favoriteColumns': 12};
    expect(
      () => LauncherSettings.decode(jsonEncode(json)),
      throwsFormatException,
    );
  });

  test('Czech sorting places Č after C and Ch between H and I', () {
    final names = ['Instagram', 'Chat', 'Čas', 'Cesta', 'Hodiny', 'Chrome'];
    names.sort(compareLabels);
    expect(names, ['Cesta', 'Čas', 'Hodiny', 'Chat', 'Chrome', 'Instagram']);
    expect(normalizeSearch('PŘÍLIŠ ŽLUŤOUČKÝ KŮŇ'), 'prilis zlutoucky kun');
    expect(normalizeSearch('Můj\n  kalendář'), 'muj kalendar');
    final softened = ['Dům', 'Dáma', 'Ďábel', 'Nos', 'Ňadra', 'Tuba', 'Ťapka'];
    softened.sort(compareLabels);
    expect(softened, ['Ďábel', 'Dáma', 'Dům', 'Ňadra', 'Nos', 'Ťapka', 'Tuba']);
  });
}
