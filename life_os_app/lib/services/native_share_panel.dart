import 'package:flutter/services.dart';

class NativeSharePanel {
  const NativeSharePanel();

  static const MethodChannel _channel =
      MethodChannel('life_os_app/share_panel');

  Future<void> shareFile({
    required String filePath,
    required String mimeType,
    required String title,
    required String text,
  }) async {
    await _channel.invokeMethod<bool>('shareFile', {
      'filePath': filePath,
      'mimeType': mimeType,
      'title': title,
      'text': text,
    });
  }
}
