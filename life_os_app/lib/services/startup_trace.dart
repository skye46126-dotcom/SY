import 'package:flutter/foundation.dart';

class StartupTrace {
  StartupTrace._();

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static final List<String> _events = <String>[];

  static void mark(String label) {
    final event = '${_stopwatch.elapsedMilliseconds}ms $label';
    _events.add(event);
    debugPrint('[startup] $event');
  }

  static List<String> snapshot() => List.unmodifiable(_events);
}
