import 'package:easylauncher/src/platform.dart';
import 'package:easylauncher/src/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one unusually long Android label does not break app discovery or persistence', () async {
    const channel = MethodChannel('one.jiri.easylauncher/platform');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final longLabel = List.filled(500, 'X').join();
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'packageName': 'test.normal',
          'activityName': 'test.Normal',
          'label': 'Normal',
        },
        {
          'packageName': 'test.long',
          'activityName': 'test.Long',
          'label': longLabel,
        },
      ],
    );
    final apps = await AndroidLauncherPlatform().getApps();
    expect(apps, hasLength(2));
    expect(apps.last.label, longLabel);
    expect(
      LauncherSettings.decode(LauncherSettings(favorites: apps).encode())
          .favorites
          .last
          .label,
      longLabel,
    );
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('app discovery skips malformed Android rows individually', () async {
    const channel = MethodChannel('one.jiri.easylauncher/platform');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const first = {
      'packageName': 'test.first',
      'activityName': 'test.First',
      'label': 'First',
    };
    const last = {
      'packageName': 'test.last',
      'activityName': 'test.Last',
      'label': 'Last',
    };
    const unicode = {
      'packageName': 'test.unicode',
      'activityName': 'test.unicode.应用',
      'label': 'Unicode',
    };
    final invalidActivity = {...first, 'activityName': 'test.Bad name'};
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        first,
        null,
        'invalid',
        {...first, 'packageName': 1},
        {...first, 'label': null},
        invalidActivity,
        unicode,
        last,
      ],
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final apps = await AndroidLauncherPlatform().getApps();
    expect(apps.map((app) => app.toJson()), [first, unicode, last]);
    expect(() => LaunchTarget.fromJson(invalidActivity), throwsFormatException);
  });

  test('blank Android labels fall back to the package name', () async {
    const channel = MethodChannel('one.jiri.easylauncher/platform');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const row = {
      'packageName': 'test.blank',
      'activityName': '.Main',
      'label': ' \u00a0\u202f\ufeff ',
    };
    messenger.setMockMethodCallHandler(channel, (_) async => [row]);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final apps = await AndroidLauncherPlatform().getApps();
    expect(apps.single.label, 'test.blank');
    expect(apps.single.activityName, 'test.blank.Main');
    expect(() => LaunchTarget.fromJson(row), throwsFormatException);
  });

  test('HOME reaches both navigation and controller event consumers', () async {
    const channel = MethodChannel('one.jiri.easylauncher/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final platform = AndroidLauncherPlatform();
    final navigation = <String>[];
    final controller = <String>[];
    final first = platform.events.listen(navigation.add);
    final second = platform.events.listen(controller.add);
    await Future<void>.delayed(Duration.zero);
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeSuccessEnvelope({'type': 'home'}),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(navigation, ['home']);
    expect(controller, ['home']);
    await first.cancel();
    await second.cancel();
    messenger.setMockMethodCallHandler(channel, null);
  });
}
