import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/config_models.dart';
import '../../services/native_voice_capture.dart';
import '../../services/startup_trace.dart';
import '../../shared/widgets/module_page.dart';
import 'capture_launch.dart';
import 'capture_controller.dart';
import 'widgets/ai_capture_section.dart';
import 'widgets/capture_shell.dart';
import 'widgets/capture_type_selector.dart';
import 'widgets/quick_capture_pool_section.dart';
import 'widgets/record_form_section.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    this.launchConfig,
  });

  final CaptureLaunchConfig? launchConfig;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  CaptureController? _controller;
  late final TextEditingController _aiInputController;
  late final FocusNode _aiInputFocusNode;
  final Map<String, TextEditingController> _formControllers = {};
  final Set<String> _selectedProjectIds = {};
  final Set<String> _selectedTagIds = {};
  bool _metadataLoaded = false;
  bool _quickCaptureBufferLoaded = false;
  bool _launchConfigApplied = false;
  bool _voiceCaptureStarted = false;
  bool _bootstrapMarked = false;
  CaptureType? _lastAppliedType;
  CaptureWorkspaceTab _activeTab = CaptureWorkspaceTab.compose;

  @override
  void initState() {
    super.initState();
    _aiInputController = TextEditingController();
    _aiInputFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= CaptureController(LifeOsScope.of(context));
    _applyLaunchConfig();
  }

  @override
  void dispose() {
    _aiInputController.dispose();
    _aiInputFocusNode.dispose();
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
    final runtimeReady = runtime.isReady;
    final anchorDate = _captureDate(runtime);

    return AnimatedBuilder(
      animation: Listenable.merge([controller, runtime]),
      builder: (context, _) {
        _ensureMetadataLoaded(runtime, controller, anchorDate);
        _ensureQuickCaptureBufferLoaded(runtime, controller, anchorDate);
        if (!runtimeReady) {
          if (!_bootstrapMarked) {
            _bootstrapMarked = true;
            StartupTrace.mark('capture.bootstrap.visible');
          }
          return _CaptureBootstrapView(
            launchConfig: widget.launchConfig,
          );
        }
        StartupTrace.mark('capture.page.ready');
        _applyDefaults(
          type: controller.selectedType,
          metadata: controller.metadata,
          anchorDate: anchorDate,
        );
        final fieldControllers = {
          for (final field
              in captureFieldDefinitionsFor(controller.selectedType))
            field.key: _controllerFor(field.key),
        };
        return ModulePage(
          title: '录入',
          subtitle: 'Capture',
          children: [
            CaptureShell(
              selectedType: controller.selectedType,
              aiState: controller.aiState,
              activeTab: _activeTab,
              onTabChanged: (tab) {
                setState(() => _activeTab = tab);
              },
              quickCaptureBufferCount: controller.quickCaptureBufferItemCount,
              composeChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CaptureTypeSelector(
                    selectedType: controller.selectedType,
                    onChanged: (type) {
                      controller.selectType(type);
                      _applyDefaults(
                        type: type,
                        metadata: controller.metadata,
                        anchorDate: anchorDate,
                        force: true,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  RecordFormSection(
                    selectedType: controller.selectedType,
                    anchorDate: anchorDate,
                    controllers: fieldControllers,
                    submitState: controller.manualSubmitState,
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
                      controller
                          .submitManual(
                        userId: runtime.userId,
                        anchorDate: anchorDate,
                        fields: {
                          for (final entry in fieldControllers.entries)
                            entry.key: entry.value.text,
                        },
                        projectIds: _selectedProjectIds.toList(),
                        tagIds: _selectedTagIds.toList(),
                      )
                          .then((success) {
                        if (!mounted || !success) {
                          return;
                        }
                        runtime.markRecordsChanged();
                        _resetAfterSubmit(
                          type: controller.selectedType,
                          metadata: controller.metadata,
                          anchorDate: anchorDate,
                        );
                        _finishSubmitSuccess(anchorDate);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  AiCaptureComposerSection(
                    inputController: _aiInputController,
                    inputFocusNode: _aiInputFocusNode,
                    autofocusInput: widget.launchConfig?.focusAiInput ?? false,
                    parseMode: controller.selectedAiParseMode,
                    onParseModeChanged: controller.selectAiParseMode,
                    onParsePressed: () {
                      setState(() {
                        _activeTab = CaptureWorkspaceTab.review;
                      });
                      controller.parseAiInput(
                        userId: runtime.userId,
                        rawInput: _aiInputController.text,
                        contextDate: anchorDate,
                      );
                    },
                    onAddToBufferPressed: () {
                      controller
                          .appendQuickCaptureBufferItem(
                        userId: runtime.userId,
                        anchorDate: anchorDate,
                        rawText: _aiInputController.text,
                      )
                          .then((success) {
                        if (!mounted || !success) {
                          return;
                        }
                        _aiInputController.clear();
                        setState(() {
                          _activeTab = CaptureWorkspaceTab.cache;
                        });
                      });
                    },
                    quickBufferCount: controller.quickCaptureBufferItemCount,
                  ),
                ],
              ),
              reviewChild: DraftReviewCenterSection(
                aiState: controller.aiState,
                onDraftChanged: controller.updateAiDraftEnvelope,
                onCommitPressed: () {
                  final draft = controller.aiState.data;
                  if (draft == null) {
                    return;
                  }
                  controller
                      .commitAiDrafts(
                    userId: runtime.userId,
                    draftEnvelope: draft,
                  )
                      .then((success) {
                    if (!mounted || !success) {
                      return;
                    }
                    runtime.markRecordsChanged();
                    _finishSubmitSuccess(anchorDate);
                  });
                },
                optionResolver: controller.optionsFor,
                sourceSuggestions: controller.incomeSourceSuggestions,
                projectOptions: controller.projectOptions,
                tags: controller.tags,
                commitState: controller.aiCommitState,
                lastCommitSummary: controller.lastAiCommitSummary,
              ),
              cacheChild: QuickCapturePoolSection(
                bufferState: controller.quickCaptureBufferState,
                actionState: controller.quickCaptureBufferActionState,
                inputController: _aiInputController,
                lastActionSummary: controller.lastQuickCaptureBufferSummary,
                onAppendPressed: () {
                  controller
                      .appendQuickCaptureBufferItem(
                    userId: runtime.userId,
                    anchorDate: anchorDate,
                    rawText: _aiInputController.text,
                  )
                      .then((success) {
                    if (!mounted || !success) {
                      return;
                    }
                    _aiInputController.clear();
                  });
                },
                onProcessPressed: () {
                  controller
                      .processQuickCaptureBufferSession(
                    userId: runtime.userId,
                    anchorDate: anchorDate,
                    autoCommit: false,
                  )
                      .then((result) {
                    if (!mounted || result == null) {
                      return;
                    }
                    setState(() {
                      _activeTab = CaptureWorkspaceTab.review;
                    });
                  });
                },
                onDeletePressed: (itemId) {
                  if (itemId.trim().isEmpty) {
                    return;
                  }
                  controller.deleteQuickCaptureBufferItem(
                    userId: runtime.userId,
                    anchorDate: anchorDate,
                    itemId: itemId,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyLaunchConfig() {
    if (_launchConfigApplied) {
      return;
    }
    final config = widget.launchConfig;
    final controller = _controller;
    if (config == null || controller == null) {
      return;
    }
    _launchConfigApplied = true;
    if (config.initialType != null) {
      controller.selectType(config.initialType!);
    }
    final prefillText = config.prefillText;
    if (prefillText != null && _aiInputController.text.trim().isEmpty) {
      _aiInputController.text = prefillText;
    }
    if (config.focusAiInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _aiInputFocusNode.requestFocus();
      });
    }
    if (config.autoStartVoiceCapture && !_voiceCaptureStarted) {
      _voiceCaptureStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _startVoiceCapture();
      });
    }
  }

  String _captureDate(dynamic runtime) {
    final contextDate = widget.launchConfig?.contextDate?.trim() ?? '';
    return contextDate.isEmpty ? runtime.todayDate : contextDate;
  }

  void _finishSubmitSuccess(String anchorDate) {
    if (widget.launchConfig?.returnToDay != true) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacementNamed('/day/$anchorDate');
  }

  void _ensureMetadataLoaded(
    dynamic runtime,
    CaptureController controller,
    String anchorDate,
  ) {
    if (_metadataLoaded || !runtime.isReady) {
      return;
    }
    _metadataLoaded = true;
    StartupTrace.mark('capture.metadata.load.start');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller
          .loadMetadata(
        userId: runtime.userId,
      )
          .then((_) {
        if (!mounted) return;
        StartupTrace.mark('capture.metadata.load.ready');
        _applyDefaults(
          type: controller.selectedType,
          metadata: controller.metadata,
          anchorDate: anchorDate,
          force: true,
        );
      });
    });
  }

  void _ensureQuickCaptureBufferLoaded(
    dynamic runtime,
    CaptureController controller,
    String anchorDate,
  ) {
    if (_quickCaptureBufferLoaded || !runtime.isReady) {
      return;
    }
    _quickCaptureBufferLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.loadQuickCaptureBuffer(
        userId: runtime.userId,
        anchorDate: anchorDate,
      );
    });
  }

  Future<void> _startVoiceCapture() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      final transcript = await NativeVoiceCapture.capture(
        prompt: '开始语音快录',
      );
      if (!mounted) {
        return;
      }
      if (transcript == null) {
        _aiInputFocusNode.requestFocus();
        return;
      }
      _aiInputController.text = transcript;
      _aiInputFocusNode.requestFocus();
      setState(() {
        _activeTab = CaptureWorkspaceTab.review;
      });
      final runtime = LifeOsScope.runtimeOf(context);
      await controller.parseAiInput(
        userId: runtime.userId,
        rawInput: transcript,
        contextDate: _captureDate(runtime),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音快录启动失败：$error')),
      );
    }
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
        _setDefault('occurred_on', anchorDate, force: force);
        _setDefault('content', '', force: force);
        _setDefault('duration_minutes', '', force: force);
        _setDefault(
          'category_code',
          defaults?.timeCategoryCode ?? 'work',
          force: force,
        );
        _setDefault(
          'application_level_code',
          defaults?.learningLevelCode ?? 'input',
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

class _CaptureBootstrapView extends StatelessWidget {
  const _CaptureBootstrapView({
    required this.launchConfig,
  });

  final CaptureLaunchConfig? launchConfig;

  @override
  Widget build(BuildContext context) {
    final prefillText = launchConfig?.prefillText?.trim();
    return ModulePage(
      title: '录入',
      subtitle: 'Capture Bootstrap',
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          launchConfig?.mode == CaptureLaunchMode.voice
              ? '正在准备语音快录环境'
              : '正在准备快录环境',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '应用会先显示快录壳，再异步初始化数据库与录入元数据。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (prefillText != null && prefillText.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '待录入内容',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(prefillText),
            ),
          ),
        ],
      ],
    );
  }
}
