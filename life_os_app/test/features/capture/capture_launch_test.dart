import 'package:flutter_test/flutter_test.dart';
import 'package:life_os_app/features/capture/capture_controller.dart';
import 'package:life_os_app/features/capture/capture_launch.dart';

void main() {
  group('CaptureLaunchConfig', () {
    test('parses capture quick launch route', () {
      final config = CaptureLaunchConfig.fromRouteName(
        '/capture?type=learning&mode=ai&text=%E6%B5%8B%E8%AF%95',
      );

      expect(config, isNotNull);
      expect(config!.initialType, CaptureType.learning);
      expect(config.mode, CaptureLaunchMode.ai);
      expect(config.prefillText, '测试');
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
  });
}
