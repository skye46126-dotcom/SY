import '../../../services/image_export_service.dart';
import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_metadata.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class SnapshotExportBuilder {
  const SnapshotExportBuilder({
    required this.imageExporter,
    required this.archive,
  });

  final ImageExportService imageExporter;
  final ExportArchiveService archive;

  Future<ExportResult> build(ExportRequest request) async {
    final payload = request.snapshot;
    if (payload == null) {
      throw StateError('snapshot export request missing payload');
    }
    final output = await imageExporter.exportBoundary(
      boundaryKey: payload.boundaryKey,
      module: request.module,
      title: request.title,
      pixelRatio: payload.pixelRatio,
      metadata: payload.metadata,
    );
    final artifact = ExportArtifact(
      id: output.metadataPath,
      type: ExportType.snapshot,
      format: ExportFormat.png,
      module: request.module,
      title: request.title,
      filePath: output.imagePath,
      metadataPath: output.metadataPath,
      previewPath: output.imagePath,
      createdAt: output.exportedAt,
      metadata: ExportMetadata(output.metadata),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: 'snapshot exported',
    );
  }
}
