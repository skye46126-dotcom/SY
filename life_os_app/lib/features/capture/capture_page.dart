import 'package:flutter/material.dart';

import '../../app/app.dart';
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
        _controller!.loadMetadata(
          userId: LifeOsScope.runtimeOf(context).userId,
        );
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
              onChanged: controller.selectType,
            ),
            RecordFormSection(
              selectedType: controller.selectedType,
              controllers: fieldControllers,
              submitState: controller.submitState,
              projectOptions: controller.projectOptionsState.data ?? const [],
              tags: controller.tagsState.data ?? const [],
              selectedProjectIds: _selectedProjectIds,
              selectedTagIds: _selectedTagIds,
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
                );
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
}
