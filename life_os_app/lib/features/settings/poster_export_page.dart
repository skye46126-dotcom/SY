import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/poster_models.dart';
import '../../services/image_export_service.dart';
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
  final ImageExportService _imageExportService = const ImageExportService();
  PosterExportService? _posterService;
  ViewState<PosterSourceData> _sourceState = ViewState.initial();
  PosterTimeRange _selectedRange = PosterTimeRange.today;
  PosterTemplateKind _selectedTemplate = PosterTemplateKind.poster;
  PosterCoverSource _selectedCoverSource = PosterCoverSource.auto;
  PosterPrivacyPolicy _policy = PosterPrivacyPolicy.preset(
    PosterPrivacyMode.publicShare,
  );
  bool _isExporting = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _posterService ??= PosterExportService(LifeOsScope.of(context));
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
            selectedCoverSource: _selectedCoverSource,
            policy: _policy,
            onRangeChanged: _changeRange,
            onTemplateChanged: (value) {
              setState(() => _selectedTemplate = value);
            },
            onCoverSourceChanged: (value) {
              setState(() => _selectedCoverSource = value);
            },
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
    );
    setState(() => _isExporting = true);
    try {
      final result = await _imageExportService.exportBoundary(
        boundaryKey: _posterBoundaryKey,
        module: 'poster',
        title:
            'poster-${data.range.exportKey}-${data.template.exportKey}-${data.policy.mode.exportKey}',
        pixelRatio: 1,
        metadata: {
          'page': 'poster_export',
          'poster': data.toJson(),
        },
      );
      if (!mounted) return;
      await showExportDocumentDialog(context, result);
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
}

class _PosterStudioSection extends StatelessWidget {
  const _PosterStudioSection({
    required this.boundaryKey,
    required this.previewData,
    required this.selectedRange,
    required this.selectedTemplate,
    required this.selectedCoverSource,
    required this.policy,
    required this.onRangeChanged,
    required this.onTemplateChanged,
    required this.onCoverSourceChanged,
    required this.onPolicyChanged,
  });

  final GlobalKey boundaryKey;
  final PosterExportData previewData;
  final PosterTimeRange selectedRange;
  final PosterTemplateKind selectedTemplate;
  final PosterCoverSource selectedCoverSource;
  final PosterPrivacyPolicy policy;
  final ValueChanged<PosterTimeRange> onRangeChanged;
  final ValueChanged<PosterTemplateKind> onTemplateChanged;
  final ValueChanged<PosterCoverSource> onCoverSourceChanged;
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
    }
  }
}
