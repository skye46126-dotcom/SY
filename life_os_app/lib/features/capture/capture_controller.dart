import 'package:flutter/foundation.dart';

import '../../models/project_models.dart';
import '../../models/tag_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';

enum CaptureType {
  time('时间'),
  income('收入'),
  expense('支出'),
  learning('学习'),
  project('项目');

  const CaptureType(this.label);

  final String label;
}

class CaptureController extends ChangeNotifier {
  CaptureController(this._service);

  final AppService _service;

  CaptureType selectedType = CaptureType.time;
  ViewState<Map<String, Object?>> aiState = ViewState.initial();
  ViewState<void> submitState = ViewState.initial();
  ViewState<List<ProjectOption>> projectOptionsState = ViewState.initial();
  ViewState<List<TagModel>> tagsState = ViewState.initial();

  void selectType(CaptureType type) {
    if (selectedType == type) {
      return;
    }
    selectedType = type;
    notifyListeners();
  }

  Future<void> loadMetadata({
    required String userId,
  }) async {
    projectOptionsState = ViewState.loading();
    tagsState = ViewState.loading();
    notifyListeners();
    try {
      final projects = await _service.getProjectOptions(
        userId: userId,
        includeDone: true,
      );
      final tags = await _service.getTags(userId: userId);
      projectOptionsState = ViewState.ready(projects);
      tagsState = ViewState.ready(tags);
    } catch (error) {
      projectOptionsState = ViewState.error(error.toString());
      tagsState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> parseAiInput({
    required String userId,
    required String rawInput,
    required String parserMode,
  }) async {
    aiState = ViewState.loading();
    notifyListeners();
    try {
      final draft = await _service.parseAiCapture(
        userId: userId,
        rawInput: rawInput,
        parserMode: parserMode,
      );
      if (draft == null || draft.isEmpty) {
        aiState = ViewState.empty('AI 没有返回任何可确认草稿。');
      } else {
        aiState = ViewState.ready(draft);
      }
    } on UnimplementedError {
      aiState = ViewState.unavailable('AI 解析接口尚未接入 Rust。');
    } catch (error) {
      aiState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> submitManual({
    required String userId,
    required String anchorDate,
    required Map<String, String> fields,
    required List<String> projectIds,
    required List<String> tagIds,
  }) async {
    submitState = ViewState.loading();
    notifyListeners();
    try {
      switch (selectedType) {
        case CaptureType.time:
          await _service.createTimeRecord({
            'user_id': userId,
            'started_at': _toUtcTimestamp(anchorDate, fields['started_at'] ?? ''),
            'ended_at': _toUtcTimestamp(anchorDate, fields['ended_at'] ?? ''),
            'category_code': _required(fields['category_code'], '类别'),
            'efficiency_score': _parseInt(fields['efficiency_score']),
            'value_score': null,
            'state_score': null,
            'ai_assist_ratio': _parseInt(fields['ai_assist_ratio']),
            'note': _nullable(fields['note']),
            'source': 'manual',
            'is_public_pool': false,
            'project_allocations': _projectAllocations(projectIds),
            'tag_ids': tagIds,
          });
        case CaptureType.income:
          await _service.createIncomeRecord({
            'user_id': userId,
            'occurred_on': _requiredOrDefault(fields['occurred_on'], anchorDate),
            'source_name': _required(fields['source_name'], '来源'),
            'type_code': _required(fields['type_code'], '类型'),
            'amount_cents': _amountToCents(fields['amount_yuan']),
            'is_passive': _parseBool(fields['is_passive']),
            'ai_assist_ratio': _parseInt(fields['ai_assist_ratio']),
            'note': _nullable(fields['note']),
            'source': 'manual',
            'is_public_pool': false,
            'project_allocations': _projectAllocations(projectIds),
            'tag_ids': tagIds,
          });
        case CaptureType.expense:
          await _service.createExpenseRecord({
            'user_id': userId,
            'occurred_on': _requiredOrDefault(fields['occurred_on'], anchorDate),
            'category_code': _required(fields['category_code'], '类别'),
            'amount_cents': _amountToCents(fields['amount_yuan']),
            'ai_assist_ratio': _parseInt(fields['ai_assist_ratio']),
            'note': _nullable(fields['note']),
            'source': 'manual',
            'project_allocations': _projectAllocations(projectIds),
            'tag_ids': tagIds,
          });
        case CaptureType.learning:
          await _service.createLearningRecord({
            'user_id': userId,
            'occurred_on': _requiredOrDefault(fields['occurred_on'], anchorDate),
            'started_at': _optionalUtcTimestamp(anchorDate, fields['started_at']),
            'ended_at': _optionalUtcTimestamp(anchorDate, fields['ended_at']),
            'content': _required(fields['content'], '内容'),
            'duration_minutes': _requiredInt(fields['duration_minutes'], '时长'),
            'application_level_code':
                _required(fields['application_level_code'], '应用等级'),
            'efficiency_score': _parseInt(fields['efficiency_score']),
            'ai_assist_ratio': _parseInt(fields['ai_assist_ratio']),
            'note': _nullable(fields['note']),
            'source': 'manual',
            'is_public_pool': false,
            'project_allocations': _projectAllocations(projectIds),
            'tag_ids': tagIds,
          });
        case CaptureType.project:
          await _service.createProject({
            'user_id': userId,
            'name': _required(fields['name'], '项目名称'),
            'status_code': _required(fields['status_code'], '项目状态'),
            'started_on': _requiredOrDefault(fields['started_on'], anchorDate),
            'ended_on': _nullable(fields['ended_on']),
            'ai_enable_ratio': _parseInt(fields['ai_enable_ratio']),
            'score': _parseInt(fields['score']),
            'note': _nullable(fields['note']),
            'tag_ids': tagIds,
          });
      }
      submitState = ViewState.ready(null);
    } catch (error) {
      submitState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> commitAiDrafts({
    required String userId,
    required Map<String, Object?> draftEnvelope,
  }) async {
    submitState = ViewState.loading();
    notifyListeners();
    try {
      final items = ((draftEnvelope['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .toList();
      if (items.isEmpty) {
        throw ArgumentError('没有可提交的 AI 草稿');
      }
      await _service.invokeRaw(
        method: 'commit_ai_drafts',
        payload: {
          'user_id': userId,
          'request_id': draftEnvelope['request_id'],
          'context_date': draftEnvelope['context_date'],
          'drafts': items,
          'options': {
            'source': 'external',
            'auto_create_tags': false,
            'strict_reference_resolution': false,
          },
        },
      );
      submitState = ViewState.ready(null);
    } catch (error) {
      submitState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  String _required(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw ArgumentError('$label 不能为空');
    }
    return trimmed;
  }

  String _requiredOrDefault(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parseInt(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return int.parse(trimmed);
  }

  int _requiredInt(String? value, String label) {
    final parsed = _parseInt(value);
    if (parsed == null) {
      throw ArgumentError('$label 不能为空');
    }
    return parsed;
  }

  bool _parseBool(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  int _amountToCents(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw ArgumentError('金额不能为空');
    }
    return (double.parse(trimmed) * 100).round();
  }

  List<Map<String, Object?>> _projectAllocations(List<String> ids) {
    return ids
        .map((id) => {
              'project_id': id,
              'weight_ratio': 1.0,
            })
        .toList();
  }

  String _toUtcTimestamp(String date, String time) {
    final trimmedTime = time.trim();
    if (trimmedTime.isEmpty) {
      throw ArgumentError('时间不能为空');
    }
    final local = DateTime.parse('$date ${_normalizeTime(trimmedTime)}');
    return local.toUtc().toIso8601String();
  }

  String? _optionalUtcTimestamp(String date, String? time) {
    final trimmed = time?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final local = DateTime.parse('$date ${_normalizeTime(trimmed)}');
    return local.toUtc().toIso8601String();
  }

  String _normalizeTime(String value) {
    return value.length == 5 ? '$value:00' : value;
  }
}
