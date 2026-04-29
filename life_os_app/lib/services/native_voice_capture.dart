import 'package:flutter/services.dart';

class NativeVoiceCapture {
  static const MethodChannel _channel =
      MethodChannel('life_os_app/voice_capture');

  static Future<String?> capture({
    String prompt = '开始语音快录',
  }) async {
    final result = await _channel.invokeMethod<String>(
      'startVoiceCapture',
      {'prompt': prompt},
    );
    final trimmed = result?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
