import 'capture_controller.dart';

enum CaptureLaunchMode {
  manual,
  ai,
  voice,
}

class CaptureLaunchConfig {
  const CaptureLaunchConfig({
    this.initialType,
    this.mode = CaptureLaunchMode.manual,
    this.prefillText,
  });

  final CaptureType? initialType;
  final CaptureLaunchMode mode;
  final String? prefillText;

  bool get focusAiInput =>
      mode == CaptureLaunchMode.ai || mode == CaptureLaunchMode.voice;

  bool get autoStartVoiceCapture => mode == CaptureLaunchMode.voice;

  static CaptureLaunchConfig? fromRouteName(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(routeName);
    if (uri == null || uri.path != '/capture') {
      return null;
    }
    return fromUri(uri);
  }

  static CaptureLaunchConfig fromUri(Uri uri) {
    return CaptureLaunchConfig(
      initialType: _parseType(uri.queryParameters['type']),
      mode: _parseMode(uri.queryParameters['mode']),
      prefillText: _normalizedText(uri.queryParameters['text']),
    );
  }

  static CaptureType? _parseType(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'time' => CaptureType.time,
      'income' => CaptureType.income,
      'expense' => CaptureType.expense,
      'learning' => CaptureType.learning,
      'project' => CaptureType.project,
      _ => null,
    };
  }

  static CaptureLaunchMode _parseMode(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'ai' => CaptureLaunchMode.ai,
      'voice' => CaptureLaunchMode.voice,
      _ => CaptureLaunchMode.manual,
    };
  }

  static String? _normalizedText(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
