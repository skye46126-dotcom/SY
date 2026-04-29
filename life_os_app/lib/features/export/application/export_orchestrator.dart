import '../../../services/app_service.dart';
import '../../../services/image_export_service.dart';
import '../builders/backup_export_builder.dart';
import '../builders/data_package_export_builder.dart';
import '../builders/poster_export_builder.dart';
import '../builders/report_export_builder.dart';
import '../builders/snapshot_export_builder.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class ExportOrchestrator {
  ExportOrchestrator({
    required AppService service,
    ImageExportService? imageExporter,
    ExportArchiveService? archive,
  })  : archive = archive ?? const ExportArchiveService(),
        _backupBuilder = BackupExportBuilder(
          service: service,
          archive: archive ?? const ExportArchiveService(),
        ),
        _dataPackageBuilder = DataPackageExportBuilder(
          service: service,
          archive: archive ?? const ExportArchiveService(),
        ),
        _reportBuilder = ReportExportBuilder(
          service: service,
          archive: archive ?? const ExportArchiveService(),
        ),
        _snapshotBuilder = SnapshotExportBuilder(
          imageExporter: imageExporter ?? const ImageExportService(),
          archive: archive ?? const ExportArchiveService(),
        ),
        _posterBuilder = PosterExportBuilder(
          imageExporter: imageExporter ?? const ImageExportService(),
          archive: archive ?? const ExportArchiveService(),
        );

  final ExportArchiveService archive;
  final BackupExportBuilder _backupBuilder;
  final DataPackageExportBuilder _dataPackageBuilder;
  final ReportExportBuilder _reportBuilder;
  final SnapshotExportBuilder _snapshotBuilder;
  final PosterExportBuilder _posterBuilder;

  Future<Map<String, int>> previewDataPackage({
    required String userId,
  }) {
    return _dataPackageBuilder.previewCounts(userId: userId);
  }

  Future<ExportResult> export(ExportRequest request) {
    switch (request.type) {
      case ExportType.backup:
        return _backupBuilder.build(request);
      case ExportType.dataPackage:
        return _dataPackageBuilder.build(request);
      case ExportType.report:
        return _reportBuilder.build(request);
      case ExportType.snapshot:
        return _snapshotBuilder.build(request);
      case ExportType.poster:
        return _posterBuilder.build(request);
    }
  }
}
