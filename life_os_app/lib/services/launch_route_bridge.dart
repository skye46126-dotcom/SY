import 'dart:async';

import 'package:flutter/services.dart';

class LaunchRouteBridge {
  LaunchRouteBridge() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const MethodChannel _channel = MethodChannel('life_os_app/launch');

  final StreamController<String> _routes = StreamController<String>.broadcast();

  Stream<String> get routes => _routes.stream;

  Future<String?> consumeLaunchRoute() async {
    final route = await _channel.invokeMethod<String>('consumeLaunchRoute');
    return _normalizeRoute(route);
  }

  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    return _routes.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'launchRoute') {
      return;
    }
    final route = _normalizeRoute(call.arguments as String?);
    if (route != null) {
      _routes.add(route);
    }
  }

  String? _normalizeRoute(String? route) {
    final trimmed = route?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
