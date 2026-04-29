import 'package:flutter/services.dart';

class NativeImagePicker {
  const NativeImagePicker();

  static const MethodChannel _channel =
      MethodChannel('life_os_app/image_picker');

  Future<String?> pickImage() async {
    final path = await _channel.invokeMethod<String>('pickImage');
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
