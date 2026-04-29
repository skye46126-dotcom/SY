import 'dart:io';

import 'package:flutter/services.dart';

class GallerySaveResult {
  const GallerySaveResult({
    required this.uri,
    required this.album,
    required this.displayPath,
  });

  final String uri;
  final String album;
  final String displayPath;

  Map<String, Object?> toJson() {
    return {
      'gallery_uri': uri,
      'gallery_album': album,
      'gallery_path': displayPath,
    };
  }
}

class NativeGallerySaver {
  const NativeGallerySaver();

  static const MethodChannel _channel =
      MethodChannel('life_os_app/image_picker');

  Future<GallerySaveResult?> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }
    final payload = await _channel.invokeMapMethod<String, Object?>(
      'savePngToGallery',
      {
        'bytes': bytes,
        'fileName': fileName,
      },
    );
    if (payload == null) return null;
    return GallerySaveResult(
      uri: payload['uri']?.toString() ?? '',
      album: payload['album']?.toString() ?? 'SkyOS',
      displayPath: payload['displayPath']?.toString() ?? '',
    );
  }
}
