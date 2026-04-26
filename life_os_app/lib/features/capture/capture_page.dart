import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/config_models.dart';
import '../../shared/widgets/module_page.dart';
import 'capture_controller.dart';
import 'widgets/ai_capture_section.dart';
import 'widgets/capture_type_selector.dart';
import 'widgets/record_form_section.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  CaptureController? _controller;
  late final TextEditingController _aiInputController;
  final Map<String, TextEditingController> _formControllers = {};
  final Set<String> _selectedProjectIds = {};
  final Set<String> _selectedTagIds = {};
  bool _metadataLoaded = false;
  CaptureType? _lastAppliedType;

  @override
  void initState() {
    super.initState();
    _aiInputController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= CaptureController(LifeOsScope.of(context));
    if (!_metadataLoaded) {
      _metadataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller!
            .loadMetadata(
          userId: LifeOsScope.runtimeOf(context).userId,
        )
            .then((_) {
          if (!mounted) return;
          _applyDefaults(
            type: _controller!.selectedType,
            metadata: _controller!.metadata,
            anchorDate: LifeOsScope.runtimeOf(context).todayDate,
            force: true,
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _aiInputController.dispose();
    for (final controller in _formControllers.values) {
      controller.dispose();
    }
    _controller?.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String key) {
    return _formControllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final runtime = LifeOsScope.runtimeOf(context);
    final date = runtime.todayDate;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _applyDefaults(
          type: controller.selectedType,
          metadata: controller.metadata,
          anchorDate: runtime.todayDate,
        );
        final fieldControllers = {
          for (final field in captureFieldDefinitionsFor(controller.selectedType))
            field.key: _controllerFor(field.key),
        };
        return ModulePage(
          title: '快速录入中心',
          subtitle: 'Capture',
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/day/$date'),
              child: const Text('当日详情'),
            ),
          ],
          children: [
            CaptureTypeSelector(
              selectedType: controller.selectedType,
              onChanged: (type) {
                controller.selectType(type);
                _applyDefaults(
                  type: type,
                  metadata: controller.metadata,
                  anchorDate: runtime.todayDate,
                  force: true,
                );
              },
            ),
            RecordFormSection(
              selectedType: controller.selectedType,
              anchorDate: runtime.todayDate,
              controllers: fieldControllers,
              submitState: controller.submitState,
              projectOptions: controller.projectOptions,
              tags: controller.tags,
              selectedProjectIds: _selectedProjectIds,
              selectedTagIds: _selectedTagIds,
              optionResolver: controller.optionsFor,
              sourceSuggestions: controller.incomeSourceSuggestions,
              onProjectToggle: (projectId) {
                setState(() {
                  if (_selectedProjectIds.contains(projectId)) {
                    _selectedProjectIds.remove(projectId);
                  } else {
                    _selectedProjectIds.add(projectId);
                  }
                });
              },
              onTagToggle: (tagId) {
                setState(() {
                  if (_selectedTagIds.contains(tagId)) {
                    _selectedTagIds.remove(tagId);
                  } else {
                    _selectedTagIds.add(tagId);
                  }
                });
              },
              onSubmit: () {
                controller.submitManual(
                  userId: runtime.userId,
                  anchorDate: runtime.todayDate,
                  fields: {
                    for (final entry in fieldControllers.entries)
                      entry.key: entry.value.text,
                  },
                  projectIds: _selectedProjectIds.toList(),
                  tagIds: _selectedTagIds.toList(),
                ).then((success) {
                  if (!mounted || !success) {
                    return;
                  }
                  _resetAfterSubmit(
                    type: controller.selectedType,
                    metadata: controller.metadata,
                    anchorDate: runtime.todayDate,
                  );
                });
              },
            ),
            AiCaptureSection(
              aiState: controller.aiState,
              inputController: _aiInputController,
              onParsePressed: () {
                controller.parseAiInput(
                  userId: runtime.userId,
                  rawInput: _aiInputController.text,
                  parserMode: 'balanced',
                );
              },
              onCommitPressed: () {
                final draft = controller.aiState.data;
                if (draft == null) {
                  return;
                }
                controller.commitAiDrafts(
                  userId: runtime.userId,
                  draftEnvelope: draft,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _applyDefaults({
    required CaptureType type,
    required CaptureMetadataModel? metadata,
    required String anchorDate,
    bool force = false,
  }) {
    if (!force && _lastAppliedType == type) {
      return;
    }
    final fields = captureFieldDefinitionsFor(type);
    for (final field in fields) {
      _controllerFor(field.key);
    }
    final defaults = metadata?.defaults;
    switch (type) {
      case CaptureType.time:
        _setDefault('started_at', _roundedNow(), force: force);
        _setDefault(
          'ended_at',
          _offsetTime(_formControllers['started_at']!.text, 30),
          force: force,
        );
        _setDefault(
          'category_code',
          defaults?.timeCategoryCode ?? 'work',
          force: force,
        );
        _setDefault('ai_assist_ratio', '', force: force);
        _setDefault('efficiency_score', '', force: force);
        _setDefault('value_score', '', force: force);
        _setDefault('state_score', '', force: force);
        _setDefault('note', '', force: force);
      case CaptureType.income:
        _setDefault('occurred_on', anchorDate, force: force);
        _setDefault(
          'type_code',
          defaults?.incomeTypeCode ?? 'project',
          force: force,
        );
        _setDefault('source_name', '', force: force);
        _setDefault('amount_yuan', '', force: force);
        _setDefault('is_passive', 'false', force: force);
        _setDefault('ai_assist_ratio', '', force: force);
        _setDefault('note', '', force: force);
      case CaptureType.expense:
        _setDefault('occurred_on', anchorDate, force: force);
        _setDefault(
          'category_code',
          defaults?.expenseCategoryCode ?? 'necessary',
          force: force,
        );
        _setDefault('amount_yuan', '', force: force);
        _setDefault('ai_assist_ratio', '', force: force);
        _setDefault('note', '', force: force);
      case CaptureType.learning:
        _setDefault('occurred_on', anchorDate, force: force);
        _setDefault('content', '', force: force);
        _setDefault('duration_minutes', '', force: force);
        _setDefault(
          'application_level_code',
          defaults?.learningLevelCode ?? 'input',
          force: force,
        );
        _setDefault('started_at', '', force: force);
        _setDefault('ended_at', '', force: force);
        _setDefault('ai_assist_ratio', '', force: force);
        _setDefault('efficiency_score', '', force: force);
        _setDefault('note', '', force: force);
      case CaptureType.project:
        _setDefault('name', '', force: force);
        _setDefault('started_on', anchorDate, force: force);
        _setDefault(
          'status_code',
          defaults?.projectStatusCode ?? 'active',
          force: force,
        );
        _setDefault('score', '', force: force);
        _setDefault('ai_enable_ratio', '', force: force);
        _setDefault('note', '', force: force);
        _setDefault('ended_on', '', force: force);
    }
    _lastAppliedType = type;
  }

  void _resetAfterSubmit({
    required CaptureType type,
    required CaptureMetadataModel? metadata,
    required String anchorDate,
  }) {
    final fields = captureFieldDefinitionsFor(type);
    for (final field in fields) {
      _controllerFor(field.key).clear();
    }
    _applyDefaults(
      type: type,
      metadata: metadata,
      anchorDate: anchorDate,
      force: true,
    );
    setState(() {});
  }

  void _setDefault(String key, String value, {required bool force}) {
    final controller = _controllerFor(key);
    if (force || controller.text.trim().isEmpty) {
      controller.text = value;
    }
  }

  String _roundedNow() {
    final now = DateTime.now();
    final roundedMinute = (now.minute / 5).round() * 5;
    final hour = roundedMinute == 60 ? (now.hour + 1) % 24 : now.hour;
    final minute = roundedMinute == 60 ? 0 : roundedMinute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _offsetTime(String base, int minutes) {
    final parts = base.split(':');
    if (parts.length < 2) {
      return _roundedNow();
    }
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    final total = hour * 60 + minute + minutes;
    final normalized = total % (24 * 60);
    final nextHour = normalized ~/ 60;
    final nextMinute = normalized % 60;
    return '${nextHour.toString().padLeft(2, '0')}:${nextMinute.toString().padLeft(2, '0')}';
  }
}
