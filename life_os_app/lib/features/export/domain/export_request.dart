import 'package:flutter/widgets.dart';

import '../../../models/poster_models.dart';
import 'export_format.dart';
import 'export_policy.dart';
import 'export_range.dart';
import 'export_type.dart';

class BackupExportPayload {
  const BackupExportPayload({
    required this.userId,
    this.backupType = 'manual',
  });

  final String userId;
  final String backupType;
}

class PosterExportPayload {
  const PosterExportPayload({
    required this.boundaryKey,
    required this.data,
    required this.coverSource,
    required this.template,
  });

  final GlobalKey boundaryKey;
  final PosterExportData data;
  final PosterCoverSource coverSource;
  final PosterTemplateKind template;
}

class SnapshotExportPayload {
  const SnapshotExportPayload({
    required this.boundaryKey,
    required this.metadata,
    this.pixelRatio,
  });

  final GlobalKey boundaryKey;
  final Map<String, Object?> metadata;
  final double? pixelRatio;
}

class DataPackageExportPayload {
  const DataPackageExportPayload({
    required this.userId,
  });

  final String userId;
}

class ReportExportPayload {
  const ReportExportPayload({
    required this.userId,
    required this.anchorDate,
    required this.timezone,
    this.language = 'zh',
    this.customStartDate,
    this.customEndDate,
  });

  final String userId;
  final String anchorDate;
  final String timezone;
  final String language;
  final String? customStartDate;
  final String? customEndDate;
}

class ExportRequest {
  const ExportRequest({
    required this.type,
    required this.format,
    required this.range,
    required this.title,
    required this.module,
    this.policy,
    this.backup,
    this.dataPackage,
    this.report,
    this.snapshot,
    this.poster,
  });

  final ExportType type;
  final ExportFormat format;
  final ExportRange range;
  final String title;
  final String module;
  final ExportPolicy? policy;
  final BackupExportPayload? backup;
  final DataPackageExportPayload? dataPackage;
  final ReportExportPayload? report;
  final SnapshotExportPayload? snapshot;
  final PosterExportPayload? poster;

  factory ExportRequest.backup({
    required String title,
    required String userId,
    String backupType = 'manual',
  }) {
    return ExportRequest(
      type: ExportType.backup,
      format: ExportFormat.sqlite,
      range: ExportRange.all,
      title: title,
      module: 'backup',
      backup: BackupExportPayload(
        userId: userId,
        backupType: backupType,
      ),
    );
  }

  factory ExportRequest.poster({
    required String title,
    required ExportFormat format,
    required ExportRange range,
    required ExportPolicy policy,
    required PosterExportData data,
    required GlobalKey boundaryKey,
    required PosterTemplateKind template,
    required PosterCoverSource coverSource,
  }) {
    return ExportRequest(
      type: ExportType.poster,
      format: format,
      range: range,
      title: title,
      module: 'poster',
      policy: policy,
      poster: PosterExportPayload(
        boundaryKey: boundaryKey,
        data: data,
        coverSource: coverSource,
        template: template,
      ),
    );
  }

  factory ExportRequest.snapshot({
    required String title,
    required String module,
    required ExportRange range,
    required GlobalKey boundaryKey,
    required Map<String, Object?> metadata,
    double? pixelRatio,
  }) {
    return ExportRequest(
      type: ExportType.snapshot,
      format: ExportFormat.png,
      range: range,
      title: title,
      module: module,
      snapshot: SnapshotExportPayload(
        boundaryKey: boundaryKey,
        metadata: metadata,
        pixelRatio: pixelRatio,
      ),
    );
  }

  factory ExportRequest.dataPackage({
    required String title,
    required ExportFormat format,
    required String userId,
  }) {
    return ExportRequest(
      type: ExportType.dataPackage,
      format: format,
      range: ExportRange.all,
      title: title,
      module: 'data_package',
      dataPackage: DataPackageExportPayload(userId: userId),
    );
  }

  factory ExportRequest.report({
    required String title,
    required ExportFormat format,
    required ExportRange range,
    required String userId,
    required String anchorDate,
    required String timezone,
    String language = 'zh',
    String? customStartDate,
    String? customEndDate,
  }) {
    return ExportRequest(
      type: ExportType.report,
      format: format,
      range: range,
      title: title,
      module: 'report',
      report: ReportExportPayload(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
        language: language,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
      ),
    );
  }
}
