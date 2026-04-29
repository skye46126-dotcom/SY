import 'package:flutter_test/flutter_test.dart';
import 'package:life_os_app/models/poster_models.dart';
import 'package:life_os_app/services/poster_export_service.dart';

void main() {
  group('PosterExportService', () {
    const service = PosterExportService();

    test('public policy hides exact project name and money amount', () {
      final data = service.buildPosterData(
        source: _source(),
        template: PosterTemplateKind.poster,
        coverSource: PosterCoverSource.auto,
        policy: PosterPrivacyPolicy.preset(PosterPrivacyMode.publicShare),
      );

      expect(data.projectLabel, 'Primary Project');
      final finance = data.metrics.firstWhere((item) => item.key == 'finance');
      expect(finance.label, 'Finance');
      expect(finance.value, 'Positive');
    });

    test('public summary does not leak exact money values', () {
      final data = service.buildPosterData(
        source: _source(
          summaryText: '净收入为正，约 ¥1161.00，支出 320.00 元。',
        ),
        template: PosterTemplateKind.poster,
        coverSource: PosterCoverSource.auto,
        policy: PosterPrivacyPolicy.preset(PosterPrivacyMode.publicShare),
      );

      expect(data.summary, isNot(contains('1161')));
      expect(data.summary, isNot(contains('320')));
      expect(data.summary, contains('现金流'));
    });

    test('private policy shows exact project name and exact balance', () {
      final data = service.buildPosterData(
        source: _source(),
        template: PosterTemplateKind.minimal,
        coverSource: PosterCoverSource.auto,
        policy: PosterPrivacyPolicy.preset(PosterPrivacyMode.privateReview),
      );

      expect(data.projectLabel, 'SkyeOS Export Module');
      final finance = data.metrics.firstWhere((item) => item.key == 'finance');
      expect(finance.label, 'Balance');
      expect(finance.value, '¥540');
    });

    test('policy flags remove optional metrics and keywords', () {
      final data = service.buildPosterData(
        source: _source(aiRatio: 0.42),
        template: PosterTemplateKind.poster,
        coverSource: PosterCoverSource.auto,
        policy:
            PosterPrivacyPolicy.preset(PosterPrivacyMode.limitedShare).copyWith(
          showAiRatio: false,
          showKeywords: false,
          showProject: false,
        ),
      );

      expect(data.metrics.where((item) => item.key == 'ai'), isEmpty);
      expect(data.keywords, isEmpty);
      expect(data.projectLabel, isNull);
    });

    test('manual cover source overrides automatic theme selection', () {
      final data = service.buildPosterData(
        source: _source(),
        template: PosterTemplateKind.poster,
        coverSource: PosterCoverSource.growthMint,
        policy: PosterPrivacyPolicy.preset(PosterPrivacyMode.publicShare),
      );

      expect(data.coverSource, PosterCoverSource.growthMint);
      expect(data.themeKey, 'growth_mint');
    });
  });
}

PosterSourceData _source({
  double? aiRatio = 0.42,
  String summaryText = 'Today was focused and steady.',
}) {
  return PosterSourceData(
    range: PosterTimeRange.today,
    anchorDate: DateTime(2026, 4, 27),
    dateLabel: 'Apr 27, 2026',
    periodLabel: 'Daily Status',
    summaryText: summaryText,
    financeStateLabel: 'Positive',
    netIncomeCents: 54000,
    incomeCents: 86000,
    expenseCents: 32000,
    workMinutes: 220,
    learningMinutes: 80,
    aiRatio: aiRatio,
    passiveCoverRatio: 1.18,
    actualHourlyRateCents: 26000,
    idealHourlyRateCents: 24000,
    primaryProjectName: 'SkyeOS Export Module',
    keywordPool: const ['focus', 'clarity', 'steady'],
    incomeChangeRatio: 0.18,
    expenseChangeRatio: -0.07,
    workChangeRatio: 0.11,
  );
}
