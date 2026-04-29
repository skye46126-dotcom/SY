import 'dart:async';

import 'package:flutter/services.dart';

import '../app/app_runtime.dart';
import 'app_service.dart';

class QuickCaptureShellBridge {
  QuickCaptureShellBridge({
    required AppService service,
    required AppRuntimeController runtime,
  })  : _service = service,
        _runtime = runtime {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const MethodChannel _channel =
      MethodChannel('life_os_app/quick_capture_shell');

  final AppService _service;
  final AppRuntimeController _runtime;

  Future<void> dispose() {
    _channel.setMethodCallHandler(null);
    return Future<void>.value();
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'submitQuickCapture':
        final args = (call.arguments as Map?)?.cast<String, Object?>();
        if (args == null) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Quick capture arguments are required.',
          );
        }
        return _submitQuickCapture(args);
      default:
        throw MissingPluginException();
    }
  }

  Future<Map<String, Object?>> _submitQuickCapture(
    Map<String, Object?> args,
  ) async {
    final profile = await _runtime.waitUntilReady();
    final rawText = (args['rawText'] as String? ?? '').trim();
    if (rawText.isEmpty) {
      throw PlatformException(
        code: 'empty_text',
        message: 'Quick capture text is empty.',
      );
    }
    final source = (args['source'] as String? ?? 'native_shell').trim();
    final entryPoint =
        (args['entryPoint'] as String? ?? 'quick_capture_shell').trim();
    final routeHint =
        (args['routeHint'] as String? ?? '/capture?mode=ai').trim();
    final modeHint = (args['modeHint'] as String? ?? 'ai').trim();

    final enqueueResult = await _service.invokeRaw(
      method: 'enqueue_capture_inbox',
      payload: {
        'user_id': profile.id,
        'source': source,
        'entry_point': entryPoint,
        'raw_text': rawText,
        'context_date': _runtime.todayDate,
        'route_hint': routeHint,
        'mode_hint': modeHint,
      },
    );
    final entry = (enqueueResult as Map).cast<String, Object?>();
    final inboxId = entry['id']?.toString();
    if (inboxId == null || inboxId.isEmpty) {
      throw PlatformException(
        code: 'missing_inbox_id',
        message: 'Quick capture inbox entry id is missing.',
      );
    }

    final autoResult = await _service.invokeRaw(
      method: 'process_capture_inbox_and_commit',
      payload: {
        'user_id': profile.id,
        'inbox_id': inboxId,
      },
    );
    final autoMap = (autoResult as Map).cast<String, Object?>();
    final commitResult =
        (autoMap['commit_result'] as Map?)?.cast<String, Object?>();
    final committedCount =
        ((commitResult?['committed'] as List?) ?? const []).length;
    final failures = ((commitResult?['failures'] as List?) ?? const []).length;
    final noteFailures =
        ((commitResult?['note_failures'] as List?) ?? const []).length;
    final shouldReview =
        commitResult == null || failures > 0 || noteFailures > 0;

    return {
      'status': shouldReview ? 'needs_review' : 'committed',
      'inbox_id': inboxId,
      'committed_count': committedCount,
      'route': '$routeHint&text=${Uri.encodeComponent(rawText)}',
    };
  }
}
