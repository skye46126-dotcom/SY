import 'package:flutter_test/flutter_test.dart';
import 'package:life_os_app/features/capture/capture_controller.dart';
import 'package:life_os_app/features/capture/capture_launch.dart';

void main() {
  group('CaptureLaunchConfig', () {
    test('parses capture quick launch route', () {
      final config = CaptureLaunchConfig.fromRouteName(
        '/capture?type=learning&mode=ai&text=%E6%B5%8B%E8%AF%95&contextDate=2026-04-20&returnTo=day',
      );

      expect(config, isNotNull);
      expect(config!.initialType, CaptureType.time);
      expect(config.mode, CaptureLaunchMode.ai);
      expect(config.prefillText, '测试');
      expect(config.contextDate, '2026-04-20');
      expect(config.returnToDay, isTrue);
      expect(config.focusAiInput, isTrue);
    });

    test('ignores non capture routes', () {
      final config = CaptureLaunchConfig.fromRouteName('/today');

      expect(config, isNull);
    });

    test('falls back on unknown values', () {
      final config = CaptureLaunchConfig.fromRouteName(
        '/capture?type=unknown&mode=custom',
      );

      expect(config, isNotNull);
      expect(config!.initialType, isNull);
      expect(config.mode, CaptureLaunchMode.manual);
      expect(config.focusAiInput, isFalse);
    });

    test('parses voice launch mode', () {
      final config = CaptureLaunchConfig.fromRouteName('/capture?mode=voice');

      expect(config, isNotNull);
      expect(config!.mode, CaptureLaunchMode.voice);
      expect(config.focusAiInput, isTrue);
      expect(config.autoStartVoiceCapture, isTrue);
    });
  });
}
