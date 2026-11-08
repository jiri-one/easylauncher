import 'package:easylauncher/main.dart' as app;
import 'package:easylauncher/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native discovery, profile persistence and drawer work on Android', (
    tester,
  ) async {
    await app.main();
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('clock')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    final controller = tester
        .widget<app.EasyLauncherApp>(find.byType(app.EasyLauncherApp))
        .controller;
    final platform = controller.platform;
    final installed = await platform.getApps();
    expect(installed, isNotEmpty);
    expect(
      installed.every(
        (target) => target.packageName != 'one.jiri.easylauncher.debug',
      ),
      isTrue,
    );
    expect(
      installed.map((target) => target.id).toSet().length,
      installed.length,
    );
    final saved = await platform.loadSettings();
    expect(saved, isNotNull);
    expect(
      LauncherSettings.decode(saved!).encode(),
      controller.settings.encode(),
    );

    await expectLater(
      platform.launchApp(
        const LaunchTarget(
          packageName: 'test.easylauncher.nonexistent',
          activityName: 'test.easylauncher.nonexistent.MainActivity',
          label: 'Missing app',
        ),
      ),
      throwsA(isA<PlatformException>()),
    );
    final status = await platform.getStatus();
    debugPrint(
      'Native apps: ${installed.length}; default: ${status.isDefault}; notifications: ${status.notificationsEnabled}',
    );

    await tester.tap(find.byKey(const ValueKey('open-apps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final target = controller.visibleApps().firstOrNull;
    await tester.enterText(
      find.byKey(const ValueKey('app-search')),
      target?.label ?? 'no-such-app',
    );
    await tester.pumpAndSettle();
    if (target != null) {
      expect(find.byKey(ValueKey('app-${target.id}')), findsOneWidget);
    }
    await tester.drag(
      target == null
          ? find.text('Aplikace')
          : find.byKey(const ValueKey('app-list')),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clock')), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugPrint(
      'Profile favorites: ${controller.settings.favorites.length}; native smoke test passed',
    );
  });
}
