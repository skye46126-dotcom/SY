import '../../../services/app_service.dart';
import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_metadata.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class BackupExportBuilder {
  const BackupExportBuilder({
    required this.service,
    required this.archive,
  });

  final AppService service;
  final ExportArchiveService archive;

  Future<ExportResult> build(ExportRequest request) async {
    final payload = request.backup;
    if (payload == null) {
      throw StateError('backup export request missing payload');
    }
    final result = await service.createBackup(
      userId: payload.userId,
      backupType: payload.backupType,
    );
    final metadataPath = '${result.filePath}.export.json';
    final artifact = ExportArtifact(
      id: result.id,
      type: ExportType.backup,
      format: ExportFormat.sqlite,
      module: request.module,
      title: request.title,
      filePath: result.filePath,
      metadataPath: metadataPath,
      createdAt: DateTime.tryParse(result.createdAt) ?? DateTime.now(),
      metadata: ExportMetadata({
        'backup_type': result.backupType,
        'file_size_bytes': result.fileSizeBytes,
        'checksum': result.checksum,
        'success': result.success,
        'error_message': result.errorMessage,
      }),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: result.success ? 'backup exported' : 'backup export failed',
    );
  }
}
