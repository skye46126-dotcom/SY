import 'package:flutter/foundation.dart';

import '../../models/config_models.dart';
import '../../models/project_models.dart';
import '../../models/tag_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';

enum CaptureType {
  time('时间'),
  income('收入'),
  expense('支出'),
  project('项目');

  const CaptureType(this.label);

  final String label;
}

enum AiCaptureParseMode {
  auto('自动', 'Auto'),
  fast('快速', 'Fast'),
  deep('深度', 'Deep');

  const AiCaptureParseMode(this.label, this.bridgeValue);

  final String label;
  final String bridgeValue;
}

enum CaptureFieldOptions {
  timeCategory,
  incomeType,
  expenseCategory,
  learningLevel,
  projectStatus,
}

class CaptureController extends ChangeNotifier {
  CaptureController(this._service);

  final AppService _service;

  CaptureType selectedType = CaptureType.time;
  AiCaptureParseMode selectedAiParseMode = AiCaptureParseMode.auto;
  ViewState<Map<String, Object?>> aiState = ViewState.initial();
  ViewState<void> manualSubmitState = ViewState.initial();
  ViewState<void> aiCommitState = ViewState.initial();
  ViewState<Map<String, Object?>> quickCaptureBufferState = ViewState.initial();
  ViewState<void> quickCaptureBufferActionState = ViewState.initial();
  ViewState<CaptureMetadataModel> metadataState = ViewState.initial();
  String? lastAiCommitSummary;
  String? lastQuickCaptureBufferSummary;

  CaptureMetadataModel? get metadata => metadataState.data;

  List<ProjectOption> get projectOptions =>
      metadataState.data?.projectOptions ?? const [];

  List<TagModel> get tags => metadataState.data?.tags ?? const [];

  List<String> get incomeSourceSuggestions =>
      metadataState.data?.incomeSourceSuggestions ?? const [];

  List<DimensionOptionModel> optionsFor(CaptureFieldOptions key) {
    final metadata = metadataState.data;
    if (metadata == null) {
      return const [];
    }
    return switch (key) {
      CaptureFieldOptions.timeCategory => metadata.timeCategories,
      CaptureFieldOptions.incomeType => metadata.incomeTypes,
      CaptureFieldOptions.expenseCategory => metadata.expenseCategories,
      CaptureFieldOptions.learningLevel => metadata.learningLevels,
      CaptureFieldOptions.projectStatus => metadata.projectStatuses,
    };
  }

  void selectType(CaptureType type) {
    if (selectedType == type) {
      return;
    }
    selectedType = type;
    notifyListeners();
  }

  void selectAiParseMode(AiCaptureParseMode mode) {
    if (selectedAiParseMode == mode) {
      return;
    }
    selectedAiParseMode = mode;
    notifyListeners();
  }

  Future<void> loadMetadata({
    required String userId,
  }) async {
    metadataState = ViewState.loading();
    notifyListeners();
    try {
      final response = await _service.invokeRaw(
        method: 'get_capture_metadata',
        payload: {'user_id': userId},
      );
      metadataState = ViewState.ready(
        CaptureMetadataModel.fromJson(
            (response as Map).cast<String, dynamic>()),
      );
    } catch (error) {
      metadataState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> parseAiInput({
    required String userId,
    required String rawInput,
    required String contextDate,
  }) async {
    lastAiCommitSummary = null;
    aiCommitState = ViewState.initial();
    aiState = ViewState.loading();
    notifyListeners();
    try {
      final response = await _service.invokeRaw(
        method: 'parse_ai_input_v2',
        payload: {
          'user_id': userId,
          'raw_text': rawInput,
          'context_date': contextDate,
          'parser_mode_override': selectedAiParseMode.bridgeValue,
        },
      );
      final draft = response is Map ? response.cast<String, Object?>() : null;
      if (draft == null || draft.isEmpty) {
        aiState = ViewState.empty('AI 没有返回任何可确认草稿。');
      } else {
        draft['context_date'] ??= contextDate;
        aiState = ViewState.ready(draft);
      }
    } on UnimplementedError {
      aiState = ViewState.unavailable('AI 解析接口尚未接入 Rust。');
    } catch (error) {
      aiState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  void updateAiDraftEnvelope(Map<String, Object?> draftEnvelope) {
    aiCommitState = ViewState.initial();
    aiState = ViewState.ready(draftEnvelope);
    notifyListeners();
  }

  Future<void> loadQuickCaptureBuffer({
    required String userId,
    required String anchorDate,
  }) async {
    quickCaptureBufferState = ViewState.loading();
    notifyListeners();
    try {
      final session = await _service.invokeRaw(
        method: 'get_or_create_active_capture_buffer_session',
        payload: {
          'user_id': userId,
          'source': 'app_capture',
          'entry_point': 'capture_workspace',
          'context_date': anchorDate,
          'route_hint': '/capture?mode=ai',
          'mode_hint': 'ai',
        },
      );
      final sessionMap = (session as Map).cast<String, Object?>();
      final listed = await _service.invokeRaw(
        method: 'list_capture_buffer_items',
        payload: {
          'user_id': userId,
          'session_id': sessionMap['id'],
        },
      );
      final listedMap = (listed as Map).cast<String, Object?>();
      quickCaptureBufferState = ViewState.ready({
        'session': sessionMap,
        'items': ((listedMap['items'] as List?) ?? const []).toList(),
      });
    } catch (error) {
      quickCaptureBufferState = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<bool> appendQuickCaptureBufferItem({
    required String userId,
    required String anchorDate,
    required String rawText,
    String inputKind = 'text',
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      quickCaptureBufferActionState = ViewState.error('请输入要加入缓存的内容');
      notifyListeners();
      return false;
    }
    lastQuickCaptureBufferSummary = null;
    quickCaptureBufferActionState = ViewState.loading();
    notifyListeners();
    try {
      final sessionId = currentQuickCaptureSessionId;
      await _service.invokeRaw(
        method: 'append_capture_buffer_item',
        payload: {
          'user_id': userId,
          'session_id': sessionId,
          'source': 'app_capture',
          'entry_point': 'capture_workspace',
          'raw_text': trimmed,
          'context_date': anchorDate,
          'route_hint': '/capture?mode=ai',
          'mode_hint': 'ai',
          'input_kind': inputKind,
        },
      );
      await loadQuickCaptureBuffer(userId: userId, anchorDate: anchorDate);
      final count = quickCaptureBufferItemCount;
      lastQuickCaptureBufferSummary = '已加入缓存池，当前共 $count 条';
      quickCaptureBufferActionState = ViewState.ready(null);
      notifyListeners();
      return true;
    } catch (error) {
      quickCaptureBufferActionState = ViewState.error(error.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuickCaptureBufferItem({
    required String userId,
    required String anchorDate,
    required String itemId,
  }) async {
    final sessionId = currentQuickCaptureSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      quickCaptureBufferActionState = ViewState.error('当前没有可操作的缓存会话');
      notifyListeners();
      return false;
    }
    lastQuickCaptureBufferSummary = null;
    quickCaptureBufferActionState = ViewState.loading();
    notifyListeners();
    try {
      await _service.invokeRaw(
        method: 'delete_capture_buffer_item',
        payload: {
          'user_id': userId,
          'session_id': sessionId,
          'item_id': itemId,
        },
      );
      await loadQuickCaptureBuffer(userId: userId, anchorDate: anchorDate);
      lastQuickCaptureBufferSummary = '已移除 1 条缓存内容';
      quickCaptureBufferActionState = ViewState.ready(null);
      notifyListeners();
      return true;
    } catch (error) {
      quickCaptureBufferActionState = ViewState.error(error.toString());
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, Object?>?> processQuickCaptureBufferSession({
    required String userId,
    required String anchorDate,
    bool autoCommit = false,
  }) async {
    final sessionId = currentQuickCaptureSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      quickCaptureBufferActionState = ViewState.error('当前没有可整理的缓存内容');
      notifyListeners();
      return null;
    }
    lastQuickCaptureBufferSummary = null;
    quickCaptureBufferActionState = ViewState.loading();
    notifyListeners();
    try {
      final result = await _service.invokeRaw(
        method: 'process_capture_buffer_session',
        payload: {
          'user_id': userId,
          'session_id': sessionId,
          'auto_commit': autoCommit,
        },
      );
      final resultMap = (result as Map).cast<String, Object?>();
      final processResult = ((resultMap['process_result'] as Map?) ?? const {})
          .cast<String, Object?>();
      final draftEnvelope =
          ((processResult['draft_envelope'] as Map?) ?? const {})
              .cast<String, Object?>();
      if (draftEnvelope.isNotEmpty) {
        draftEnvelope['context_date'] ??= anchorDate;
        aiCommitState = ViewState.initial();
        aiState = ViewState.ready(draftEnvelope);
      }
      await loadQuickCaptureBuffer(userId: userId, anchorDate: anchorDate);
      lastQuickCaptureBufferSummary =
          autoCommit ? '缓存内容已整理并尝试自动入库' : '缓存内容已整理，草稿已送入审核区';
      quickCaptureBufferActionState = ViewState.ready(null);
      notifyListeners();
      return resultMap;
    } catch (error) {
      quickCaptureBufferActionState = ViewState.error(error.toString());
      notifyListeners();
      return null;
    }
  }

  String? get currentQuickCaptureSessionId {
    final data = quickCaptureBufferState.data;
    if (data == null) {
      return null;
    }
    final session =
        ((data['session'] as Map?) ?? const {}).cast<String, Object?>();
    final id = session['id']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  int get quickCaptureBufferItemCount {
    final data = quickCaptureBufferState.data;
    if (data == null) {
      return 0;
    }
    return ((data['items'] as List?) ?? const []).length;
  }

  Future<bool> submitManual({
    required String userId,
    required String anchorDate,
    required Map<String, String> fields,
    required List<String> projectIds,
    required List<String> tagIds,
  }) async {
    lastAiCommitSummary = null;
    manualSubmitState = ViewState.loading();
    notifyListeners();
    try {
      switch (selectedType) {
        case CaptureType.time:
          await _service.createTimeRecord({
            'user_id': userId,
            'occurred_on':
                _requiredOrDefault(fields['occurred_on'], anchorDate),
            'started_at':
                _optionalUtcTimestamp(anchorDate, fields['started_at']),
            'ended_at': _optionalUtcTimestamp(anchorDate, fields['ended_at']),
            'duration_minutes': _parseInt(fields['duration_minutes']),
            'category_code': _required(fields['category_code'], '类别'),
            'content': _required(fields['content'], '内容'),
            'application_level_code':
                _nullable(fields['application_level_code']),
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
            'occurred_on':
                _requiredOrDefault(fields['occurred_on'], anchorDate),
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
            'occurred_on':
                _requiredOrDefault(fields['occurred_on'], anchorDate),
            'category_code': _required(fields['category_code'], '类别'),
            'amount_cents': _amountToCents(fields['amount_yuan']),
            'ai_assist_ratio': _parseInt(fields['ai_assist_ratio']),
            'note': _nullable(fields['note']),
            'source': 'manual',
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
      manualSubmitState = ViewState.ready(null);
      notifyListeners();
      return true;
    } catch (error) {
      manualSubmitState = ViewState.error(error.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> commitAiDrafts({
    required String userId,
    required Map<String, Object?> draftEnvelope,
  }) async {
    lastAiCommitSummary = null;
    aiCommitState = ViewState.loading();
    notifyListeners();
    try {
      final items = ((draftEnvelope['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .where(_isSubmittableReviewable)
          .toList();
      final reviewNotes = ((draftEnvelope['review_notes'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .where(_isSavableReviewNote)
          .toList();
      if (items.isEmpty && reviewNotes.isEmpty) {
        throw ArgumentError('没有可提交的记录或可保存的复盘素材');
      }
      final result = await _service.invokeRaw(
        method: 'commit_ai_capture',
        payload: {
          'user_id': userId,
          'request_id': draftEnvelope['request_id'],
          'context_date': draftEnvelope['context_date'],
          'drafts': items.map(_legacyDraftFromReviewable).toList(),
          'review_notes': reviewNotes.map(_reviewNoteDraftPayload).toList(),
          'options': {
            'source': 'external',
            'auto_create_tags': false,
            'strict_reference_resolution': false,
          },
        },
      );
      final data = result is Map ? result.cast<String, Object?>() : const {};
      final committed = ((data['committed'] as List?) ?? const []).length;
      final notes = ((data['committed_notes'] as List?) ?? const []).length;
      final failures = ((data['failures'] as List?) ?? const []).length +
          ((data['note_failures'] as List?) ?? const []).length;
      final needsReview = ((draftEnvelope['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, Object?>())
          .where(_isNeedsReviewRecord)
          .where((item) => item['user_confirmed'] != true)
          .length;
      lastAiCommitSummary =
          '已入库：$committed 条；复盘素材：$notes 条；需确认跳过：$needsReview 条；失败：$failures 条';
      aiCommitState = ViewState.ready(null);
      notifyListeners();
      return failures == 0;
    } catch (error) {
      aiCommitState = ViewState.error(error.toString());
      notifyListeners();
      return false;
    }
  }

  Map<String, Object?> _legacyDraftFromReviewable(Map<String, Object?> item) {
    final kind = switch (item['kind']?.toString()) {
      'time_record' => 'time',
      'income_record' => 'income',
      'expense_record' => 'expense',
      'learning_record' => 'time',
      _ => 'unknown',
    };
    final payload = <String, String>{};
    final fields =
        ((item['fields'] as Map?) ?? const {}).cast<String, Object?>();
    for (final entry in fields.entries) {
      final field = entry.value;
      if (field is Map) {
        final value = field['value'];
        if (value != null && value.toString().trim().isNotEmpty) {
          payload[entry.key] = value.toString();
        }
      }
    }
    final links = ((item['links'] as Map?) ?? const {}).cast<String, Object?>();
    final projects = ((links['projects'] as List?) ?? const [])
        .whereType<Map>()
        .map((link) => link['name']?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .join(',');
    final tags = ((links['tags'] as List?) ?? const [])
        .whereType<Map>()
        .map((link) => link['name']?.toString() ?? '')
        .where((value) => value.trim().isNotEmpty)
        .join(',');
    if (projects.isNotEmpty) payload['project_names'] = projects;
    if (tags.isNotEmpty) payload['tag_names'] = tags;
    final raw = item['raw_text']?.toString();
    if (raw != null && raw.trim().isNotEmpty) payload['raw'] = raw;
    final note = item['note']?.toString();
    if (note != null && note.trim().isNotEmpty) payload['note'] = note;

    return {
      'draft_id': item['draft_id']?.toString() ?? '',
      'kind': kind,
      'payload': payload,
      'confidence': item['confidence'] is num ? item['confidence'] : 0.0,
      'source': item['source']?.toString() ?? 'ai_v2',
      'warning': ((item['validation'] as Map?)?['warnings'] as List?)
          ?.map((value) => value.toString())
          .join('; '),
    };
  }

  Map<String, Object?> _reviewNoteDraftPayload(Map<String, Object?> note) {
    return {
      'draft_id': note['draft_id']?.toString() ?? '',
      'raw_text':
          note['raw_text']?.toString() ?? note['content']?.toString() ?? '',
      'occurred_on': note['occurred_on']?.toString(),
      'note_type': note['note_type']?.toString() ?? 'reflection',
      'title': note['title']?.toString() ?? '复盘素材',
      'content': note['content']?.toString() ?? '',
      'source': note['source']?.toString() ?? 'ai_capture',
      'visibility': note['visibility']?.toString() ?? 'compact',
      'confidence': note['confidence'] is num ? note['confidence'] : null,
      'linked_record_kind': note['linked_record_kind']?.toString(),
      'linked_record_id': note['linked_record_id']?.toString(),
    };
  }

  bool _isCommittableReviewable(Map<String, Object?> item) {
    final kind = item['kind']?.toString();
    if (!{
      'time_record',
      'income_record',
      'expense_record',
    }.contains(kind)) {
      return false;
    }
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    final status = validation['status']?.toString();
    return status == 'commit_ready' || status == 'needs_review';
  }

  bool _isCommitReadyReviewable(Map<String, Object?> item) {
    if (!_isCommittableReviewable(item)) {
      return false;
    }
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'commit_ready';
  }

  bool _isSubmittableReviewable(Map<String, Object?> item) {
    if (_isCommitReadyReviewable(item)) {
      return true;
    }
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'needs_review' &&
        item['user_confirmed'] == true;
  }

  bool _isNeedsReviewRecord(Map<String, Object?> item) {
    if (!_isCommittableReviewable(item)) {
      return false;
    }
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'needs_review';
  }

  bool _isSavableReviewNote(Map<String, Object?> item) {
    final content = item['content']?.toString().trim() ?? '';
    final visibility = item['visibility']?.toString() ?? 'compact';
    return content.isNotEmpty && visibility != 'hidden';
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
