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
      case 'prepareQuickCaptureBuffer':
        return _prepareQuickCaptureBuffer();
      case 'appendQuickCaptureBuffer':
        final args = (call.arguments as Map?)?.cast<String, Object?>();
        if (args == null) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Quick capture arguments are required.',
          );
        }
        return _appendQuickCaptureBuffer(args);
      case 'processQuickCaptureBuffer':
        final args = (call.arguments as Map?)?.cast<String, Object?>();
        if (args == null) {
          throw PlatformException(
            code: 'invalid_arguments',
            message: 'Quick capture arguments are required.',
          );
        }
        return _processQuickCaptureBuffer(args);
      default:
        throw MissingPluginException();
    }
  }

  Future<Map<String, Object?>> _prepareQuickCaptureBuffer() async {
    final profile = await _runtime.waitUntilReady();
    final session = await _service.invokeRaw(
      method: 'get_or_create_active_capture_buffer_session',
      payload: {
        'user_id': profile.id,
        'source': 'native_shell',
        'entry_point': 'quick_capture_shell',
        'context_date': _runtime.todayDate,
        'route_hint': '/capture?mode=ai',
        'mode_hint': 'ai',
      },
    );
    final sessionMap = (session as Map).cast<String, Object?>();
    final listed = await _service.invokeRaw(
      method: 'list_capture_buffer_items',
      payload: {
        'user_id': profile.id,
        'session_id': sessionMap['id'],
      },
    );
    final listedMap = (listed as Map).cast<String, Object?>();
    final items = ((listedMap['items'] as List?) ?? const []);
    return {
      'session_id': sessionMap['id'],
      'item_count': items.length,
    };
  }

  Future<Map<String, Object?>> _appendQuickCaptureBuffer(
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
    final sessionId = (args['sessionId'] as String?)?.trim();

    final appendResult = await _service.invokeRaw(
      method: 'append_capture_buffer_item',
      payload: {
        'user_id': profile.id,
        'session_id': sessionId?.isEmpty ?? true ? null : sessionId,
        'source': source,
        'entry_point': entryPoint,
        'raw_text': rawText,
        'context_date': _runtime.todayDate,
        'route_hint': routeHint,
        'mode_hint': modeHint,
        'input_kind': 'text',
      },
    );
    final appendMap = (appendResult as Map).cast<String, Object?>();
    final session =
        ((appendMap['session'] as Map?) ?? const {}).cast<String, Object?>();
    final item =
        ((appendMap['item'] as Map?) ?? const {}).cast<String, Object?>();
    final resolvedSessionId = session['id']?.toString();
    if (resolvedSessionId == null || resolvedSessionId.isEmpty) {
      throw PlatformException(
        code: 'missing_session_id',
        message: 'Quick capture buffer session id is missing.',
      );
    }
    final listed = await _service.invokeRaw(
      method: 'list_capture_buffer_items',
      payload: {
        'user_id': profile.id,
        'session_id': resolvedSessionId,
      },
    );
    final listedMap = (listed as Map).cast<String, Object?>();
    final items = ((listedMap['items'] as List?) ?? const []);

    return {
      'status': 'buffered',
      'session_id': resolvedSessionId,
      'item_id': item['id'],
      'item_count': items.length,
    };
  }

  Future<Map<String, Object?>> _processQuickCaptureBuffer(
    Map<String, Object?> args,
  ) async {
    final profile = await _runtime.waitUntilReady();
    final sessionId = (args['sessionId'] as String? ?? '').trim();
    if (sessionId.isEmpty) {
      throw PlatformException(
        code: 'missing_session_id',
        message: 'Quick capture buffer session id is missing.',
      );
    }
    final processed = await _service.invokeRaw(
      method: 'process_capture_buffer_session',
      payload: {
        'user_id': profile.id,
        'session_id': sessionId,
        'auto_commit': true,
      },
    );
    final processedMap = (processed as Map).cast<String, Object?>();
    final session =
        ((processedMap['session'] as Map?) ?? const {}).cast<String, Object?>();
    final autoCommit =
        (processedMap['auto_commit_result'] as Map?)?.cast<String, Object?>();
    final commitResult =
        (autoCommit?['commit_result'] as Map?)?.cast<String, Object?>();
    final committedCount =
        ((commitResult?['committed'] as List?) ?? const []).length;
    final failures = ((commitResult?['failures'] as List?) ?? const []).length;
    final noteFailures =
        ((commitResult?['note_failures'] as List?) ?? const []).length;
    final combinedText = processedMap['combined_text']?.toString() ?? '';
    final routeHint =
        session['route_hint']?.toString().trim().isNotEmpty == true
            ? session['route_hint']!.toString()
            : '/capture?mode=ai';
    final shouldReview =
        commitResult == null || failures > 0 || noteFailures > 0;
    if (!shouldReview && committedCount > 0) {
      _runtime.markRecordsChanged();
    }
    return {
      'status': shouldReview ? 'needs_review' : 'committed',
      'session_id': sessionId,
      'committed_count': committedCount,
      'item_count': session['item_count'] ?? 0,
      'route': '$routeHint&text=${Uri.encodeComponent(combinedText)}',
    };
  }
}
