import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/audio/sensory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('haptics follow current settings and stop after disposal', () async {
    var settings = const SensorySettings(sound: false, haptics: false);
    final calls = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final service = SensoryService(settings: () => settings);
    service.tap();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    settings = const SensorySettings(sound: false);
    service.tap();
    service.correct();
    service.retry();
    service.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
    await service.dispose();
    service.streak();
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(4));
  });
  test('platform haptic failures never escape an interaction', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final service = SensoryService(settings: () => const SensorySettings(sound: false));
    service.sparkle();
    await Future<void>.delayed(Duration.zero);
    await service.dispose();
  });
}
