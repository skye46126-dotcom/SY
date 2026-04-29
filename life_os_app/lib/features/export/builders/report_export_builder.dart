import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/overview_models.dart';
import '../../../models/review_models.dart';
import '../../../services/app_service.dart';
import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_metadata.dart';
import '../domain/export_range.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class ReportExportBuilder {
  const ReportExportBuilder({
    required this.service,
    required this.archive,
  });

  final AppService service;
  final ExportArchiveService archive;

  Future<ExportResult> build(ExportRequest request) async {
    final payload = request.report;
    if (payload == null) {
      throw StateError('report export request missing payload');
    }

    final reportData = await _loadReportData(
      userId: payload.userId,
      timezone: payload.timezone,
      anchorDate: payload.anchorDate,
      range: request.range,
      customStartDate: payload.customStartDate,
      customEndDate: payload.customEndDate,
    );
    final moduleDirectory = Directory(
      await archive.preferredModuleDirectoryPath(request.module),
    );
    await moduleDirectory.create(recursive: true);
    final baseName = _fileSafeName(request.title);

    switch (request.format) {
      case ExportFormat.markdown:
        return _exportMarkdown(request, reportData, moduleDirectory, baseName);
      case ExportFormat.txt:
        return _exportTxt(request, reportData, moduleDirectory, baseName);
      case ExportFormat.pdf:
        return _exportPdf(request, reportData, moduleDirectory, baseName);
      default:
        throw StateError('unsupported report format: ${request.format.key}');
    }
  }

  Future<_ReportDataBundle> _loadReportData({
    required String userId,
    required String timezone,
    required String anchorDate,
    required ExportRange range,
    String? customStartDate,
    String? customEndDate,
  }) async {
    final anchor = DateTime.parse(anchorDate);
    switch (range) {
      case ExportRange.today:
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
        final review = await service.getReviewReport(
          userId: userId,
          timezone: timezone,
          window: ReviewWindow(
            kind: ReviewWindowKind.day,
            periodName: anchorDate,
            startDate: anchorDate,
            endDate: anchorDate,
            previousStartDate: _iso(anchor.subtract(const Duration(days: 1))),
            previousEndDate: _iso(anchor.subtract(const Duration(days: 1))),
          ),
        );
        return _ReportDataBundle(
          range: range,
          anchorDate: anchorDate,
          periodLabel: 'Daily Report',
          todayOverview: overview,
          todaySummary: summary,
          reviewReport: review,
        );
      case ExportRange.week:
      case ExportRange.month:
      case ExportRange.year:
      case ExportRange.custom:
      case ExportRange.all:
        final review = await service.getReviewReport(
          userId: userId,
          timezone: timezone,
          window: _windowForRange(
            range,
            anchor,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
          ),
        );
        return _ReportDataBundle(
          range: range,
          anchorDate: anchorDate,
          periodLabel: _periodLabel(range),
          reviewReport: review,
        );
    }
  }

  Future<ExportResult> _exportMarkdown(
    ExportRequest request,
    _ReportDataBundle data,
    Directory outputDirectory,
    String baseName,
  ) async {
    final file = File('${outputDirectory.path}/$baseName.md');
    final content = _buildMarkdown(data);
    await file.writeAsString(content, flush: true);
    final artifact = ExportArtifact(
      id: file.path,
      type: ExportType.report,
      format: ExportFormat.markdown,
      module: request.module,
      title: request.title,
      filePath: file.path,
      metadataPath: '',
      createdAt: DateTime.now(),
      metadata: ExportMetadata(_metadata(data)),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: 'report markdown exported',
    );
  }

  Future<ExportResult> _exportTxt(
    ExportRequest request,
    _ReportDataBundle data,
    Directory outputDirectory,
    String baseName,
  ) async {
    final file = File('${outputDirectory.path}/$baseName.txt');
    final content = _buildTxt(data);
    await file.writeAsString(content, flush: true);
    final artifact = ExportArtifact(
      id: file.path,
      type: ExportType.report,
      format: ExportFormat.txt,
      module: request.module,
      title: request.title,
      filePath: file.path,
      metadataPath: '',
      createdAt: DateTime.now(),
      metadata: ExportMetadata(_metadata(data)),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: 'report txt exported',
    );
  }

  Future<ExportResult> _exportPdf(
    ExportRequest request,
    _ReportDataBundle data,
    Directory outputDirectory,
    String baseName,
  ) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            request.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(data.periodLabel),
          pw.SizedBox(height: 20),
          ..._buildPdfSections(data),
        ],
      ),
    );
    final file = File('${outputDirectory.path}/$baseName.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    final artifact = ExportArtifact(
      id: file.path,
      type: ExportType.report,
      format: ExportFormat.pdf,
      module: request.module,
      title: request.title,
      filePath: file.path,
      metadataPath: '',
      createdAt: DateTime.now(),
      metadata: ExportMetadata(_metadata(data)),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: 'report pdf exported',
    );
  }

  String _buildMarkdown(_ReportDataBundle data) {
    final buffer = StringBuffer();
    buffer.writeln('# ${data.periodLabel}');
    buffer.writeln();
    buffer.writeln('- Anchor Date: ${data.anchorDate}');
    buffer.writeln('- Range: ${data.range.key}');
    buffer.writeln();
    if (data.todayOverview != null) {
      buffer.writeln('## Today Overview');
      buffer.writeln('- Income: ${data.todayOverview!.totalIncomeCents}');
      buffer.writeln('- Expense: ${data.todayOverview!.totalExpenseCents}');
      buffer.writeln('- Net: ${data.todayOverview!.netIncomeCents}');
      buffer.writeln('- Work Minutes: ${data.todayOverview!.totalWorkMinutes}');
      buffer.writeln(
          '- Learning Minutes: ${data.todayOverview!.totalLearningMinutes}');
      buffer.writeln();
    }
    if (data.todaySummary != null) {
      buffer.writeln('## Today Summary');
      buffer.writeln(data.todaySummary!.headline);
      buffer.writeln();
    }
    if (data.reviewReport != null) {
      final report = data.reviewReport!;
      buffer.writeln('## Review Summary');
      buffer.writeln(report.aiSummary);
      buffer.writeln();
      buffer.writeln('## Metrics');
      buffer.writeln('- Income: ${report.totalIncomeCents}');
      buffer.writeln('- Operating Expense: ${report.totalExpenseCents}');
      buffer.writeln('- Work Minutes: ${report.totalWorkMinutes}');
      buffer.writeln('- AI Ratio: ${report.aiAssistRate}');
      buffer.writeln('- Passive Cover: ${report.passiveCoverRatio}');
      buffer.writeln();
      if (report.topProjects.isNotEmpty) {
        buffer.writeln('## Top Projects');
        for (final item in report.topProjects.take(5)) {
          buffer.writeln(
            '- ${item.projectName}: income ${item.incomeEarnedCents}, fully loaded ROI ${item.fullyLoadedRoiPerc.toStringAsFixed(2)}%',
          );
        }
        buffer.writeln();
      }
      if (report.timeTagMetrics.isNotEmpty) {
        buffer.writeln('## Time Tags');
        for (final item in report.timeTagMetrics.take(5)) {
          buffer.writeln('- ${item.tagName}: ${item.value}');
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  String _buildTxt(_ReportDataBundle data) {
    return _buildMarkdown(data)
        .replaceAll('# ', '')
        .replaceAll('## ', '')
        .replaceAll('- ', '* ');
  }

  List<pw.Widget> _buildPdfSections(_ReportDataBundle data) {
    final widgets = <pw.Widget>[];
    if (data.todayOverview != null) {
      widgets.add(
        pw.Header(level: 1, child: pw.Text('Today Overview')),
      );
      widgets.add(pw.Text('Income: ${data.todayOverview!.totalIncomeCents}'));
      widgets.add(pw.Text('Expense: ${data.todayOverview!.totalExpenseCents}'));
      widgets.add(pw.Text('Net: ${data.todayOverview!.netIncomeCents}'));
      widgets.add(
          pw.Text('Work Minutes: ${data.todayOverview!.totalWorkMinutes}'));
      widgets.add(pw.Text(
          'Learning Minutes: ${data.todayOverview!.totalLearningMinutes}'));
      widgets.add(pw.SizedBox(height: 12));
    }
    if (data.todaySummary != null) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Today Summary')));
      widgets.add(pw.Text(data.todaySummary!.headline));
      widgets.add(pw.SizedBox(height: 12));
    }
    if (data.reviewReport != null) {
      final report = data.reviewReport!;
      widgets.add(pw.Header(level: 1, child: pw.Text('Review Summary')));
      widgets.add(pw.Text(report.aiSummary));
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text('Income: ${report.totalIncomeCents}'));
      widgets.add(pw.Text('Operating Expense: ${report.totalExpenseCents}'));
      widgets.add(pw.Text('Work Minutes: ${report.totalWorkMinutes}'));
      widgets.add(pw.Text('AI Ratio: ${report.aiAssistRate ?? 'N/A'}'));
      widgets
          .add(pw.Text('Passive Cover: ${report.passiveCoverRatio ?? 'N/A'}'));
      if (report.topProjects.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 12));
        widgets.add(pw.Header(level: 2, child: pw.Text('Top Projects')));
        for (final item in report.topProjects.take(5)) {
          widgets.add(
            pw.Text(
              '${item.projectName}: income ${item.incomeEarnedCents}, ROI ${item.fullyLoadedRoiPerc.toStringAsFixed(2)}%',
            ),
          );
        }
      }
    }
    return widgets;
  }

  Map<String, dynamic> _metadata(_ReportDataBundle data) {
    return {
      'range': data.range.key,
      'anchor_date': data.anchorDate,
      'period_label': data.periodLabel,
      'has_today_overview': data.todayOverview != null,
      'has_review_report': data.reviewReport != null,
    };
  }

  ReviewWindow _windowForRange(
    ExportRange range,
    DateTime anchor, {
    String? customStartDate,
    String? customEndDate,
  }) {
    switch (range) {
      case ExportRange.week:
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
      case ExportRange.month:
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
      case ExportRange.year:
        final start = DateTime(anchor.year, 1, 1);
        final end = DateTime(anchor.year, 12, 31);
        return ReviewWindow(
          kind: ReviewWindowKind.year,
          periodName: '${anchor.year}',
          startDate: _iso(start),
          endDate: _iso(end),
          previousStartDate: _iso(DateTime(anchor.year - 1, 1, 1)),
          previousEndDate: _iso(DateTime(anchor.year - 1, 12, 31)),
        );
      case ExportRange.custom:
        final start = DateTime.parse(customStartDate ?? _iso(anchor));
        final end = DateTime.parse(customEndDate ?? _iso(anchor));
        return _rangeWindow(
          start: start,
          end: end,
        );
      case ExportRange.all:
        final end = DateTime(anchor.year, anchor.month, anchor.day);
        final start = DateTime(1970, 1, 1);
        return _rangeWindow(
          start: start,
          end: end,
          periodName: 'All data through ${_iso(end)}',
        );
      default:
        throw StateError('unsupported report range ${range.key}');
    }
  }

  ReviewWindow _rangeWindow({
    required DateTime start,
    required DateTime end,
    String? periodName,
  }) {
    var normalizedStart = DateTime(start.year, start.month, start.day);
    var normalizedEnd = DateTime(end.year, end.month, end.day);
    if (normalizedEnd.isBefore(normalizedStart)) {
      final temp = normalizedStart;
      normalizedStart = normalizedEnd;
      normalizedEnd = temp;
    }
    final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
    return ReviewWindow(
      kind: ReviewWindowKind.range,
      periodName:
          periodName ?? '${_iso(normalizedStart)} - ${_iso(normalizedEnd)}',
      startDate: _iso(normalizedStart),
      endDate: _iso(normalizedEnd),
      previousStartDate:
          _iso(normalizedStart.subtract(Duration(days: dayCount))),
      previousEndDate: _iso(normalizedEnd.subtract(Duration(days: dayCount))),
    );
  }

  String _periodLabel(ExportRange range) {
    switch (range) {
      case ExportRange.today:
        return 'Daily Report';
      case ExportRange.week:
        return 'Weekly Report';
      case ExportRange.month:
        return 'Monthly Report';
      case ExportRange.year:
        return 'Yearly Report';
      case ExportRange.custom:
        return 'Custom Range Report';
      case ExportRange.all:
        return 'All Data Report';
    }
  }

  String _iso(DateTime value) => value.toIso8601String().split('T').first;

  String _fileSafeName(String value) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${slug.isEmpty ? 'report' : slug}_$timestamp';
  }
}

class _ReportDataBundle {
  const _ReportDataBundle({
    required this.range,
    required this.anchorDate,
    required this.periodLabel,
    this.todayOverview,
    this.todaySummary,
    this.reviewReport,
  });

  final ExportRange range;
  final String anchorDate;
  final String periodLabel;
  final TodayOverview? todayOverview;
  final TodaySummaryModel? todaySummary;
  final ReviewReport? reviewReport;
}
