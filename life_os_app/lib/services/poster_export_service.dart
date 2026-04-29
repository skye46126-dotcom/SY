import '../models/poster_models.dart';
import '../models/review_models.dart';
import 'app_service.dart';
import 'poster_cover_selector.dart';

class PosterExportService {
  const PosterExportService([
    this._service,
    this._coverSelector = const PosterCoverSelector(),
  ]);

  final AppService? _service;
  final PosterCoverSelector _coverSelector;

  Future<PosterSourceData> loadSource({
    required String userId,
    required String timezone,
    required String anchorDate,
    required PosterTimeRange range,
  }) async {
    final service = _service;
    if (service == null) {
      throw StateError('PosterExportService 缺少 AppService，无法加载海报源数据。');
    }
    switch (range) {
      case PosterTimeRange.today:
        return _loadDailySource(
          service: service,
          userId: userId,
          timezone: timezone,
          anchorDate: anchorDate,
        );
      case PosterTimeRange.week:
        return _loadReviewSource(
          service: service,
          userId: userId,
          timezone: timezone,
          anchorDate: anchorDate,
          range: PosterTimeRange.week,
        );
      case PosterTimeRange.month:
        return _loadReviewSource(
          service: service,
          userId: userId,
          timezone: timezone,
          anchorDate: anchorDate,
          range: PosterTimeRange.month,
        );
    }
  }

  PosterExportData buildPosterData({
    required PosterSourceData source,
    required PosterTemplateKind template,
    required PosterCoverSource coverSource,
    required PosterPrivacyPolicy policy,
    String? coverImagePath,
    String? coverImageLabel,
  }) {
    final stateScore = _buildStateScore(source);
    final stateLabel = _stateLabel(stateScore);
    final projectLabel = _projectLabel(source.primaryProjectName, policy);
    final keywords = _keywords(source.keywordPool, policy);
    final coverAsset = _coverSelector.resolve(
      source: source,
      coverSource: coverSource,
      imagePath: coverImagePath,
      imageLabel: coverImageLabel,
    );
    final themeKey = coverAsset.themeKey;

    final metrics = <PosterMetricData>[
      if (policy.showWorkMinutes)
        PosterMetricData(
          key: 'work',
          label: source.range == PosterTimeRange.today ? 'Focus' : 'Work',
          value: _hours(source.workMinutes),
          note: _workNote(source.workChangeRatio),
          tone: 'primary',
        ),
      if (policy.showLearningMinutes)
        PosterMetricData(
          key: 'learn',
          label: 'Learn',
          value: _hours(source.learningMinutes),
          note: source.learningMinutes > 0 ? '学习节奏在线' : '留出一点学习带宽',
          tone: 'secondary',
        ),
      if (policy.showAiRatio && source.aiRatio != null)
        PosterMetricData(
          key: 'ai',
          label: 'AI',
          value: _ratio(source.aiRatio),
          note: (source.aiRatio ?? 0) >= 0.35 ? '协作稳定' : '仍有提升空间',
          tone: 'accent',
        ),
      _financeMetric(source, policy),
      if (policy.showPassiveCover && source.passiveCoverRatio != null)
        PosterMetricData(
          key: 'cover',
          label: 'Cover',
          value: _ratio(source.passiveCoverRatio),
          note: (source.passiveCoverRatio ?? 0) >= 1 ? '必要支出覆盖健康' : '被动覆盖仍待提升',
          tone: 'neutral',
        ),
    ];

    final trimmedMetrics = metrics.take(5).toList();
    final summary = policy.showSummary
        ? _safeSummary(source, policy, stateLabel)
        : _fallbackSummary(source, stateLabel);

    return PosterExportData(
      range: source.range,
      template: template,
      coverSource: coverSource,
      coverAsset: coverAsset,
      policy: policy,
      brandLabel: 'SkyOS',
      title: _titleForRange(source.range),
      periodLabel: source.periodLabel,
      dateLabel: source.dateLabel,
      stateScore: stateScore,
      stateLabel: stateLabel,
      summary: summary,
      projectLabel: policy.showProject ? projectLabel : null,
      keywords: policy.showKeywords ? keywords : const [],
      themeKey: themeKey,
      metrics: trimmedMetrics,
      generatedAt: DateTime.now(),
    );
  }

  Future<PosterSourceData> _loadDailySource({
    required AppService service,
    required String userId,
    required String timezone,
    required String anchorDate,
  }) async {
    final overview = await service.getTodayOverview(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
    final summary = await service.getTodaySummary(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
    final report = await service.getReviewReport(
      userId: userId,
      timezone: timezone,
      window: _buildWindow(PosterTimeRange.today, anchorDate),
    );

    if (overview == null || report == null) {
      throw StateError('今日海报数据未返回完整结果。');
    }

    return PosterSourceData(
      range: PosterTimeRange.today,
      anchorDate: DateTime.parse(anchorDate),
      dateLabel: _formatDate(DateTime.parse(anchorDate)),
      periodLabel: 'Daily Status',
      summaryText:
          summary.headline.isEmpty ? report.aiSummary : summary.headline,
      financeStateLabel:
          _financeStateLabel(summary.financeStatus, overview.netIncomeCents),
      netIncomeCents: overview.netIncomeCents,
      incomeCents: overview.totalIncomeCents,
      expenseCents: overview.totalExpenseCents,
      workMinutes: overview.totalWorkMinutes,
      learningMinutes: overview.totalLearningMinutes,
      aiRatio: report.aiAssistRate,
      passiveCoverRatio: report.passiveCoverRatio,
      actualHourlyRateCents: summary.actualHourlyRateCents,
      idealHourlyRateCents: summary.idealHourlyRateCents,
      primaryProjectName: report.topProjects.isEmpty
          ? null
          : report.topProjects.first.projectName,
      keywordPool: _extractKeywords(report),
      incomeChangeRatio: report.incomeChangeRatio,
      expenseChangeRatio: report.expenseChangeRatio,
      workChangeRatio: report.workChangeRatio,
    );
  }

  Future<PosterSourceData> _loadReviewSource({
    required AppService service,
    required String userId,
    required String timezone,
    required String anchorDate,
    required PosterTimeRange range,
  }) async {
    final window = _buildWindow(range, anchorDate);
    final report = await service.getReviewReport(
      userId: userId,
      window: window,
      timezone: timezone,
    );

    if (report == null) {
      throw StateError('${range.label}海报数据未返回复盘结果。');
    }

    return PosterSourceData(
      range: range,
      anchorDate: DateTime.parse(anchorDate),
      dateLabel: _labelForWindow(report.window),
      periodLabel:
          range == PosterTimeRange.week ? 'Weekly Review' : 'Monthly Review',
      summaryText: report.aiSummary,
      financeStateLabel: _financeStateLabel(
          null, report.totalIncomeCents - report.totalExpenseCents),
      netIncomeCents: report.totalIncomeCents - report.totalExpenseCents,
      incomeCents: report.totalIncomeCents,
      expenseCents: report.totalExpenseCents,
      workMinutes: report.totalWorkMinutes,
      learningMinutes: _learningMinutesFromAllocations(report),
      aiRatio: report.aiAssistRate,
      passiveCoverRatio: report.passiveCoverRatio,
      actualHourlyRateCents: report.actualHourlyRateCents,
      idealHourlyRateCents: report.idealHourlyRateCents,
      primaryProjectName: report.topProjects.isEmpty
          ? null
          : report.topProjects.first.projectName,
      keywordPool: _extractKeywords(report),
      incomeChangeRatio: report.incomeChangeRatio,
      expenseChangeRatio: report.expenseChangeRatio,
      workChangeRatio: report.workChangeRatio,
    );
  }

  ReviewWindow _buildWindow(PosterTimeRange range, String anchorDate) {
    final anchor = DateTime.parse(anchorDate);
    switch (range) {
      case PosterTimeRange.today:
        return ReviewWindow(
          kind: ReviewWindowKind.day,
          periodName: anchorDate,
          startDate: anchorDate,
          endDate: anchorDate,
          previousStartDate: _iso(anchor.subtract(const Duration(days: 1))),
          previousEndDate: _iso(anchor.subtract(const Duration(days: 1))),
        );
      case PosterTimeRange.week:
        final weekdayOffset = anchor.weekday - DateTime.monday;
        final start = anchor.subtract(Duration(days: weekdayOffset));
        final end = start.add(const Duration(days: 6));
        return ReviewWindow(
          kind: ReviewWindowKind.week,
          periodName: '${_iso(start)} - ${_iso(end)}',
          startDate: _iso(start),
          endDate: _iso(end),
          previousStartDate: _iso(start.subtract(const Duration(days: 7))),
          previousEndDate: _iso(end.subtract(const Duration(days: 7))),
        );
      case PosterTimeRange.month:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 0);
        final previousStart = DateTime(anchor.year, anchor.month - 1, 1);
        final previousEnd = DateTime(anchor.year, anchor.month, 0);
        return ReviewWindow(
          kind: ReviewWindowKind.month,
          periodName:
              '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}',
          startDate: _iso(start),
          endDate: _iso(end),
          previousStartDate: _iso(previousStart),
          previousEndDate: _iso(previousEnd),
        );
    }
  }

  int _buildStateScore(PosterSourceData source) {
    final workTarget = switch (source.range) {
      PosterTimeRange.today => 180,
      PosterTimeRange.week => 900,
      PosterTimeRange.month => 3600,
    };
    final workScore =
        ((source.workMinutes / workTarget).clamp(0.0, 1.0) * 22).round();

    final learningTarget = switch (source.range) {
      PosterTimeRange.today => 45,
      PosterTimeRange.week => 240,
      PosterTimeRange.month => 900,
    };
    final learningScore =
        ((source.learningMinutes / learningTarget).clamp(0.0, 1.0) * 14)
            .round();

    final financeScore = source.netIncomeCents >= 0
        ? 24
        : (24 * (1 - (source.netIncomeCents.abs() / 200000).clamp(0.0, 1.0)))
            .round();

    final efficiencyRatio = source.actualHourlyRateCents != null &&
            (source.idealHourlyRateCents ?? 0) > 0
        ? (source.actualHourlyRateCents! / source.idealHourlyRateCents!)
        : 0.6;
    final efficiencyScore =
        (efficiencyRatio.clamp(0.0, 1.2) / 1.2 * 22).round();

    final coverScore = source.passiveCoverRatio == null
        ? 8
        : ((source.passiveCoverRatio!.clamp(0.0, 1.0)) * 10).round();

    final aiScore = source.aiRatio == null
        ? 8
        : ((0.55 - (source.aiRatio! - 0.45).abs()).clamp(0.0, 0.55) / 0.55 * 8)
            .round();

    final total = workScore +
        learningScore +
        financeScore +
        efficiencyScore +
        coverScore +
        aiScore;
    return total.clamp(28, 98);
  }

  String _stateLabel(int score) {
    if (score >= 82) return 'Steady';
    if (score >= 68) return 'Focused';
    if (score >= 52) return 'Recovering';
    return 'Reset';
  }

  PosterMetricData _financeMetric(
    PosterSourceData source,
    PosterPrivacyPolicy policy,
  ) {
    switch (policy.moneyDisplayMode) {
      case PosterMoneyDisplayMode.hidden:
        return PosterMetricData(
          key: 'finance',
          label: 'Finance',
          value: source.financeStateLabel,
          note: source.netIncomeCents >= 0 ? '现金流稳定' : '先控支出',
          tone: source.netIncomeCents >= 0 ? 'positive' : 'warning',
        );
      case PosterMoneyDisplayMode.trend:
        final trendValue =
            _trendLabel(source.incomeChangeRatio, source.expenseChangeRatio);
        return PosterMetricData(
          key: 'finance',
          label: 'Trend',
          value: trendValue,
          note: source.netIncomeCents >= 0 ? '本期经营状态正向' : '本期经营状态偏弱',
          tone: source.netIncomeCents >= 0 ? 'positive' : 'warning',
        );
      case PosterMoneyDisplayMode.exact:
        return PosterMetricData(
          key: 'finance',
          label: 'Balance',
          value: _currency(source.netIncomeCents),
          note:
              '收入 ${_currency(source.incomeCents)} / 支出 ${_currency(source.expenseCents)}',
          tone: source.netIncomeCents >= 0 ? 'positive' : 'warning',
        );
    }
  }

  String? _projectLabel(String? realName, PosterPrivacyPolicy policy) {
    if (realName == null || realName.trim().isEmpty) {
      return null;
    }
    switch (policy.projectDisplayMode) {
      case PosterProjectDisplayMode.category:
        return 'Primary Project';
      case PosterProjectDisplayMode.anonymous:
        return 'Project A';
      case PosterProjectDisplayMode.exact:
        return realName;
    }
  }

  List<String> _keywords(List<String> raw, PosterPrivacyPolicy policy) {
    final fallback = switch (policy.mode) {
      PosterPrivacyMode.publicShare => const ['steady', 'focus', 'clarity'],
      PosterPrivacyMode.limitedShare => const ['review', 'focus', 'balance'],
      PosterPrivacyMode.privateReview => const ['finance', 'work', 'learning'],
    };
    if (raw.isEmpty) return fallback;
    return raw.take(3).toList();
  }

  String _titleForRange(PosterTimeRange range) {
    switch (range) {
      case PosterTimeRange.today:
        return 'Daily Status';
      case PosterTimeRange.week:
        return 'Weekly Status';
      case PosterTimeRange.month:
        return 'Monthly Status';
    }
  }

  String _fallbackSummary(PosterSourceData source, String stateLabel) {
    final finance =
        source.netIncomeCents >= 0 ? 'finance positive' : 'finance under watch';
    return '${source.range.label}状态归纳为 $stateLabel，$finance。';
  }

  String _safeSummary(
    PosterSourceData source,
    PosterPrivacyPolicy policy,
    String stateLabel,
  ) {
    switch (policy.mode) {
      case PosterPrivacyMode.publicShare:
        return _publicSummary(source, stateLabel);
      case PosterPrivacyMode.limitedShare:
        return _limitedSummary(source, stateLabel);
      case PosterPrivacyMode.privateReview:
        return _trimSummary(source.summaryText);
    }
  }

  String _publicSummary(PosterSourceData source, String stateLabel) {
    final work = source.workMinutes > 0 ? '专注投入稳定' : '正在恢复节奏';
    final learn = source.learningMinutes > 0 ? '学习保持在线' : '学习带宽待补充';
    final finance = source.netIncomeCents >= 0 ? '现金流正向' : '现金流需要观察';
    return '${source.range.label}状态：$stateLabel，$work，$learn，$finance。';
  }

  String _limitedSummary(PosterSourceData source, String stateLabel) {
    final work = _workNote(source.workChangeRatio);
    final finance = source.netIncomeCents >= 0 ? '经营状态正向' : '经营状态偏弱';
    return '${source.range.label}复盘：$stateLabel，$work，$finance。';
  }

  String _trimSummary(String value) {
    final compact = value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'¥\s*-?\d+(?:\.\d+)?'), '金额已隐藏')
        .replaceAll(RegExp(r'-?\d+(?:\.\d+)?\s*元'), '金额已隐藏');
    if (compact.length <= 92) return compact;
    return '${compact.substring(0, 89)}...';
  }

  String _workNote(double? changeRatio) {
    if (changeRatio == null) return '工作节奏稳定';
    if (changeRatio > 0.08) return '投入高于上期';
    if (changeRatio < -0.08) return '投入低于上期';
    return '投入波动不大';
  }

  String _trendLabel(double? incomeChangeRatio, double? expenseChangeRatio) {
    if (incomeChangeRatio == null && expenseChangeRatio == null) {
      return 'Stable';
    }
    final incomePrefix = incomeChangeRatio == null
        ? ''
        : incomeChangeRatio >= 0
            ? 'I↑'
            : 'I↓';
    final expensePrefix = expenseChangeRatio == null
        ? ''
        : expenseChangeRatio <= 0
            ? ' E↓'
            : ' E↑';
    return '$incomePrefix$expensePrefix'.trim().isEmpty
        ? 'Stable'
        : '$incomePrefix$expensePrefix'.trim();
  }

  List<String> _extractKeywords(ReviewReport report) {
    final set = <String>{};
    for (final item in report.timeTagMetrics.take(2)) {
      if (item.tagName.trim().isNotEmpty) {
        set.add(item.tagName.trim());
      }
    }
    for (final item in report.topProjects.take(1)) {
      if (item.projectName.trim().isNotEmpty) {
        set.add(item.projectName.trim());
      }
    }
    if (set.isEmpty) {
      if ((report.aiAssistRate ?? 0) >= 0.4) set.add('ai-assisted');
      if (report.totalWorkMinutes > 0) set.add('deep-work');
      if ((report.passiveCoverRatio ?? 0) >= 1) set.add('positive');
    }
    return set.take(3).toList();
  }

  int _learningMinutesFromAllocations(ReviewReport report) {
    for (final item in report.timeAllocations) {
      final name = item.categoryName.trim().toLowerCase();
      if (name.contains('learn') ||
          name.contains('study') ||
          item.categoryName.contains('学')) {
        return item.minutes;
      }
    }
    return 0;
  }

  String _financeStateLabel(String? financeStatus, int netIncomeCents) {
    final normalized = financeStatus?.trim().toLowerCase();
    if (normalized == 'positive' || netIncomeCents >= 0) {
      return 'Positive';
    }
    if (normalized == 'neutral') {
      return 'Neutral';
    }
    return 'Watch';
  }

  String _labelForWindow(ReviewWindow window) {
    if (window.startDate == window.endDate) {
      return _formatDate(DateTime.parse(window.startDate));
    }
    return '${_shortDate(window.startDate)} - ${_shortDate(window.endDate)}';
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _shortDate(String isoDate) {
    final value = DateTime.parse(isoDate);
    return '${value.month}/${value.day}';
  }

  String _iso(DateTime value) => value.toIso8601String().split('T').first;

  String _hours(int minutes) {
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    if (hours <= 0) return '${minutes}m';
    if (remain == 0) return '${hours}h';
    return '${hours}h${remain.toString().padLeft(2, '0')}m';
  }

  String _ratio(double? value) {
    if (value == null) return 'N/A';
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  String _currency(int cents) {
    final sign = cents < 0 ? '-' : '';
    final amount = cents.abs() / 100;
    return '$sign¥${amount.toStringAsFixed(0)}';
  }
}
