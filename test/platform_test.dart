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
