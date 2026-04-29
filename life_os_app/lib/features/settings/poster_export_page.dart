import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_artifact.dart';
import '../../features/export/domain/export_format.dart';
import '../../features/export/domain/export_policy.dart';
import '../../features/export/domain/export_range.dart';
import '../../features/export/domain/export_request.dart';
import '../../models/poster_models.dart';
import '../../services/image_export_service.dart';
import '../../services/native_image_picker.dart';
import '../../services/poster_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/apple_dashboard.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/poster_preview_canvas.dart';

class PosterExportPage extends StatefulWidget {
  const PosterExportPage({super.key});

  @override
  State<PosterExportPage> createState() => _PosterExportPageState();
}

class _PosterExportPageState extends State<PosterExportPage> {
  final GlobalKey _posterBoundaryKey = GlobalKey();
  final TextEditingController _projectCoverPathController =
      TextEditingController();
  final TextEditingController _galleryImagePathController =
      TextEditingController();
  final TextEditingController _localUploadPathController =
      TextEditingController();
  final NativeImagePicker _imagePicker = const NativeImagePicker();
  PosterExportService? _posterService;
  ExportOrchestrator? _exportOrchestrator;
  ViewState<PosterSourceData> _sourceState = ViewState.initial();
  PosterTimeRange _selectedRange = PosterTimeRange.today;
  PosterTemplateKind _selectedTemplate = PosterTemplateKind.poster;
  PosterCoverSource _selectedCoverSource = PosterCoverSource.auto;
  ExportFormat _selectedFormat = ExportFormat.png;
  PosterPrivacyPolicy _policy = PosterPrivacyPolicy.preset(
    PosterPrivacyMode.publicShare,
  );
  bool _isExporting = false;
  bool _loaded = false;

  @override
  void dispose() {
    _projectCoverPathController.dispose();
    _galleryImagePathController.dispose();
    _localUploadPathController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _posterService ??= PosterExportService(LifeOsScope.of(context));
    _exportOrchestrator ??=
        ExportOrchestrator(service: LifeOsScope.of(context));
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSource();
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewData = _sourceState.hasData
        ? _posterService!.buildPosterData(
            source: _sourceState.data!,
            template: _selectedTemplate,
            coverSource: _selectedCoverSource,
            policy: _policy,
            coverImagePath: _selectedCoverImagePath,
            coverImageLabel: _selectedCoverImageLabel(_sourceState.data!),
          )
        : null;

    return AppleDashboardPage(
      title: '状态海报',
      subtitle: 'Poster Export',
      trailing: AppleCircleButton(
        icon:
            _isExporting ? Icons.downloading_rounded : Icons.ios_share_rounded,
        onPressed: previewData == null || _isExporting ? null : _exportPoster,
      ),
      controls: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ApplePill(
            label: '默认尺寸 1080×1350',
            backgroundColor: const Color(0xFFF3F6FF),
            foregroundColor: AppleDashboardPalette.primary,
          ),
          ApplePill(
            label: _policy.mode.label,
            backgroundColor: const Color(0xFFF4FBF7),
            foregroundColor: AppleDashboardPalette.success,
          ),
          ApplePill(
            label: _selectedFormat == ExportFormat.png ? 'PNG' : 'SVG',
            backgroundColor: const Color(0xFFFFF4E8),
            foregroundColor: AppleDashboardPalette.warning,
          ),
        ],
      ),
      children: [
        if (_sourceState.status == ViewStatus.loading)
          const AppleDashboardCard(
            child: SectionLoadingView(label: '正在构建海报数据'),
          ),
        if (_sourceState.status == ViewStatus.error)
          AppleDashboardCard(
            child: SectionMessageView(
              icon: Icons.image_not_supported_outlined,
              title: '海报数据暂不可用',
              description: _sourceState.message ?? '请稍后重试。',
            ),
          ),
        if (previewData != null)
          _PosterStudioSection(
            boundaryKey: _posterBoundaryKey,
            previewData: previewData,
            selectedRange: _selectedRange,
            selectedTemplate: _selectedTemplate,
            selectedFormat: _selectedFormat,
            selectedCoverSource: _selectedCoverSource,
            coverImagePath: _selectedCoverImagePath,
            policy: _policy,
            onRangeChanged: _changeRange,
            onTemplateChanged: (value) {
              setState(() => _selectedTemplate = value);
            },
            onFormatChanged: (value) {
              setState(() => _selectedFormat = value);
            },
            onCoverSourceChanged: (value) {
              setState(() => _selectedCoverSource = value);
            },
            onCoverImagePathChanged: _setSelectedCoverImagePath,
            onPickCoverImage: _pickSelectedCoverImage,
            onPolicyChanged: (policy) {
              setState(() => _policy = policy);
            },
          ),
      ],
    );
  }

  Future<void> _loadSource() async {
    setState(() => _sourceState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final source = await _posterService!.loadSource(
        userId: runtime.userId,
        timezone: runtime.timezone,
        anchorDate: runtime.todayDate,
        range: _selectedRange,
      );
      if (!mounted) return;
      setState(() => _sourceState = ViewState.ready(source));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sourceState = ViewState.error(error.toString()));
    }
  }

  Future<void> _changeRange(PosterTimeRange value) async {
    if (_selectedRange == value) return;
    setState(() => _selectedRange = value);
    await _loadSource();
  }

  Future<void> _exportPoster() async {
    final source = _sourceState.data;
    if (source == null || _isExporting) return;
    final data = _posterService!.buildPosterData(
      source: source,
      template: _selectedTemplate,
      coverSource: _selectedCoverSource,
      policy: _policy,
      coverImagePath: _selectedCoverImagePath,
      coverImageLabel: _selectedCoverImageLabel(source),
    );
    setState(() => _isExporting = true);
    try {
      final result = await _exportOrchestrator!.export(
        ExportRequest.poster(
          title:
              'poster-${data.range.exportKey}-${data.template.exportKey}-${data.policy.mode.exportKey}',
          format: _selectedFormat,
          range: _mapRange(_selectedRange),
          policy: ExportPolicy.fromPosterPolicy(_policy),
          data: data,
          boundaryKey: _posterBoundaryKey,
          template: _selectedTemplate,
          coverSource: _selectedCoverSource,
        ),
      );
      final artifact = result.primaryArtifact;
      if (!mounted) return;
      await showExportDocumentDialog(
        context,
        _artifactToImageDocument(artifact),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出海报失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  ExportRange _mapRange(PosterTimeRange range) {
    switch (range) {
      case PosterTimeRange.today:
        return ExportRange.today;
      case PosterTimeRange.week:
        return ExportRange.week;
      case PosterTimeRange.month:
        return ExportRange.month;
    }
  }

  ExportedImageDocument _artifactToImageDocument(ExportArtifact artifact) {
    return ExportedImageDocument(
      module: artifact.module,
      title: artifact.title,
      exportedAt: artifact.createdAt,
      directoryPath: File(artifact.filePath).parent.path,
      imagePath: artifact.filePath,
      metadataPath: artifact.metadataPath,
      metadata: Map<String, dynamic>.from(artifact.metadata.toJson()),
    );
  }

  String? get _selectedCoverImagePath {
    switch (_selectedCoverSource) {
      case PosterCoverSource.projectCover:
        return _projectCoverPathController.text.trim();
      case PosterCoverSource.galleryImage:
        return _galleryImagePathController.text.trim();
      case PosterCoverSource.localUpload:
        return _localUploadPathController.text.trim();
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return null;
    }
  }

  String? _selectedCoverImageLabel(PosterSourceData source) {
    switch (_selectedCoverSource) {
      case PosterCoverSource.projectCover:
        return source.primaryProjectName;
      case PosterCoverSource.galleryImage:
        return 'Gallery Image';
      case PosterCoverSource.localUpload:
        final path = _localUploadPathController.text.trim();
        return path.isEmpty
            ? 'Local Image'
            : path.split(Platform.pathSeparator).last;
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return null;
    }
  }

  void _setSelectedCoverImagePath(String value) {
    switch (_selectedCoverSource) {
      case PosterCoverSource.projectCover:
        _projectCoverPathController.text = value;
        break;
      case PosterCoverSource.galleryImage:
        _galleryImagePathController.text = value;
        break;
      case PosterCoverSource.localUpload:
        _localUploadPathController.text = value;
        break;
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return;
    }
    setState(() {});
  }

  Future<void> _pickSelectedCoverImage() async {
    try {
      final path = await _imagePicker.pickImage();
      if (path == null || !mounted) return;
      _setSelectedCoverImagePath(path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$error')),
      );
    }
  }
}

class _PosterStudioSection extends StatelessWidget {
  const _PosterStudioSection({
    required this.boundaryKey,
    required this.previewData,
    required this.selectedRange,
    required this.selectedTemplate,
    required this.selectedFormat,
    required this.selectedCoverSource,
    required this.coverImagePath,
    required this.policy,
    required this.onRangeChanged,
    required this.onTemplateChanged,
    required this.onFormatChanged,
    required this.onCoverSourceChanged,
    required this.onCoverImagePathChanged,
    required this.onPickCoverImage,
    required this.onPolicyChanged,
  });

  final GlobalKey boundaryKey;
  final PosterExportData previewData;
  final PosterTimeRange selectedRange;
  final PosterTemplateKind selectedTemplate;
  final ExportFormat selectedFormat;
  final PosterCoverSource selectedCoverSource;
  final String? coverImagePath;
  final PosterPrivacyPolicy policy;
  final ValueChanged<PosterTimeRange> onRangeChanged;
  final ValueChanged<PosterTemplateKind> onTemplateChanged;
  final ValueChanged<ExportFormat> onFormatChanged;
  final ValueChanged<PosterCoverSource> onCoverSourceChanged;
  final ValueChanged<String> onCoverImagePathChanged;
  final VoidCallback onPickCoverImage;
  final ValueChanged<PosterPrivacyPolicy> onPolicyChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1080;
        final preview = AppleDashboardCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '海报预览',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${previewData.range.label} · ${previewData.template.label}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppleDashboardPalette.secondaryText,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 1080 / 1350,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 1080,
                      height: 1350,
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: PosterPreviewCanvas(data: previewData),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final controls = AppleDashboardCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '海报配置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Text(
                '时间范围',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AppleSegmentedControl<PosterTimeRange>(
                value: selectedRange,
                onChanged: onRangeChanged,
                options: const [
                  AppleSegmentOption(value: PosterTimeRange.today, label: '今日'),
                  AppleSegmentOption(value: PosterTimeRange.week, label: '本周'),
                  AppleSegmentOption(value: PosterTimeRange.month, label: '本月'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '模板',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AppleSegmentedControl<PosterTemplateKind>(
                value: selectedTemplate,
                onChanged: onTemplateChanged,
                options: const [
                  AppleSegmentOption(
                      value: PosterTemplateKind.poster, label: '海报型'),
                  AppleSegmentOption(
                      value: PosterTemplateKind.minimal, label: '极简卡片'),
                  AppleSegmentOption(
                      value: PosterTemplateKind.magazine, label: '周报型'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '输出格式',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AppleSegmentedControl<ExportFormat>(
                value: selectedFormat,
                onChanged: onFormatChanged,
                options: const [
                  AppleSegmentOption(value: ExportFormat.png, label: 'PNG'),
                  AppleSegmentOption(value: ExportFormat.svg, label: 'SVG'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '封面来源',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final source in PosterCoverSource.values)
                    _CoverOptionTile(
                      source: source,
                      selected: selectedCoverSource == source,
                      onTap: () => onCoverSourceChanged(source),
                    ),
                ],
              ),
              if (selectedCoverSource.acceptsImagePath) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey(selectedCoverSource),
                  initialValue: coverImagePath,
                  decoration: InputDecoration(
                    labelText: _coverPathLabel(selectedCoverSource),
                    helperText: _coverPathHelper(selectedCoverSource),
                    suffixIcon: IconButton(
                      tooltip: '从相册选择',
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: onPickCoverImage,
                    ),
                  ),
                  onChanged: onCoverImagePathChanged,
                ),
              ],
              const SizedBox(height: 22),
              Text(
                '隐私模式',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final mode in PosterPrivacyMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: policy.mode == mode,
                      onSelected: (_) {
                        onPolicyChanged(PosterPrivacyPolicy.preset(mode));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '金额显示',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final mode in PosterMoneyDisplayMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: policy.moneyDisplayMode == mode,
                      onSelected: (_) {
                        onPolicyChanged(
                          policy.copyWith(moneyDisplayMode: mode),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '项目显示',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final mode in PosterProjectDisplayMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: policy.projectDisplayMode == mode,
                      onSelected: (_) {
                        onPolicyChanged(
                          policy.copyWith(projectDisplayMode: mode),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('显示内容'),
                subtitle: const Text('保留默认安全配置，再按需展开'),
                children: [
                  _SwitchRow(
                    label: '状态评分',
                    value: policy.showStateScore,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showStateScore: value));
                    },
                  ),
                  _SwitchRow(
                    label: '工作时长',
                    value: policy.showWorkMinutes,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showWorkMinutes: value));
                    },
                  ),
                  _SwitchRow(
                    label: '学习时长',
                    value: policy.showLearningMinutes,
                    onChanged: (value) {
                      onPolicyChanged(
                        policy.copyWith(showLearningMinutes: value),
                      );
                    },
                  ),
                  _SwitchRow(
                    label: 'AI 协作占比',
                    value: policy.showAiRatio,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showAiRatio: value));
                    },
                  ),
                  _SwitchRow(
                    label: '一句话总结',
                    value: policy.showSummary,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showSummary: value));
                    },
                  ),
                  _SwitchRow(
                    label: '关键词',
                    value: policy.showKeywords,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showKeywords: value));
                    },
                  ),
                  _SwitchRow(
                    label: '主项目',
                    value: policy.showProject,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showProject: value));
                    },
                  ),
                  _SwitchRow(
                    label: '被动覆盖率',
                    value: policy.showPassiveCover,
                    onChanged: (value) {
                      onPolicyChanged(policy.copyWith(showPassiveCover: value));
                    },
                  ),
                ],
              ),
            ],
          ),
        );

        if (compact) {
          return Column(
            children: [
              preview,
              const SizedBox(height: 20),
              controls,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: preview),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: controls),
          ],
        );
      },
    );
  }

  String _coverPathLabel(PosterCoverSource source) {
    switch (source) {
      case PosterCoverSource.projectCover:
        return '项目封面路径';
      case PosterCoverSource.galleryImage:
        return '画廊图片路径';
      case PosterCoverSource.localUpload:
        return '本地图片路径';
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return '图片路径';
    }
  }

  String _coverPathHelper(PosterCoverSource source) {
    switch (source) {
      case PosterCoverSource.projectCover:
        return '可填写项目封面图片的本地绝对路径，留空则使用项目封面图形。';
      case PosterCoverSource.galleryImage:
        return '填写画廊图片的本地绝对路径，留空则使用画廊图形。';
      case PosterCoverSource.localUpload:
        return '填写本地图片绝对路径，预览和 PNG 导出会读取该文件。';
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return '';
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
    );
  }
}

class _CoverOptionTile extends StatelessWidget {
  const _CoverOptionTile({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final PosterCoverSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 182,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF3F6FF)
              : Colors.white.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF9CB8FF)
                : Colors.white.withValues(alpha: 0.56),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: _coverSwatch(source)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              source.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              source.helperText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _coverSwatch(PosterCoverSource source) {
    switch (source) {
      case PosterCoverSource.auto:
        return const [Color(0xFF6B8DFF), Color(0xFF8ADFD5)];
      case PosterCoverSource.focusBlue:
        return const [Color(0xFF5F89FF), Color(0xFF1D49C6)];
      case PosterCoverSource.growthMint:
        return const [Color(0xFF8AE8D8), Color(0xFF208A78)];
      case PosterCoverSource.amberReset:
        return const [Color(0xFFF7C36A), Color(0xFFD87D19)];
      case PosterCoverSource.calmSilver:
        return const [Color(0xFFDAE4F5), Color(0xFF8EA8D7)];
      case PosterCoverSource.projectCover:
        return const [Color(0xFF4F46E5), Color(0xFF0F766E)];
      case PosterCoverSource.galleryImage:
        return const [Color(0xFFCBD5E1), Color(0xFF64748B)];
      case PosterCoverSource.localUpload:
        return const [Color(0xFF111827), Color(0xFF2F6BFF)];
    }
  }
}
