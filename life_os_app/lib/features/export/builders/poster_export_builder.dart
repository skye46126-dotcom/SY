import 'dart:io';

import '../../../services/image_export_service.dart';
import '../../../services/poster_svg_renderer.dart';
import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_metadata.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class PosterExportBuilder {
  const PosterExportBuilder({
    required this.imageExporter,
    required this.archive,
    this.svgRenderer = const PosterSvgRenderer(),
  });

  final ImageExportService imageExporter;
  final ExportArchiveService archive;
  final PosterSvgRenderer svgRenderer;

  Future<ExportResult> build(ExportRequest request) async {
    final payload = request.poster;
    if (payload == null) {
      throw StateError('poster export request missing payload');
    }
    if (request.format == ExportFormat.svg) {
      return _buildSvg(request, payload);
    }
    final output = await imageExporter.exportBoundary(
      boundaryKey: payload.boundaryKey,
      module: request.module,
      title: request.title,
      pixelRatio: 1,
      metadata: {
        'page': 'poster_export',
        'poster': payload.data.toJson(),
        'export_policy': request.policy?.toJson(),
      },
    );
    final artifact = ExportArtifact(
      id: output.metadataPath,
      type: ExportType.poster,
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
      message: 'poster exported',
    );
  }

  Future<ExportResult> _buildSvg(
    ExportRequest request,
    PosterExportPayload payload,
  ) async {
    final root =
        Directory(await archive.preferredModuleDirectoryPath(request.module));
    await root.create(recursive: true);
    final fileName =
        '${request.title.replaceAll(RegExp(r"[^a-zA-Z0-9_\\-]+"), "_")}.svg';
    final file = File('${root.path}/$fileName');
    final content = svgRenderer.render(payload.data);
    await file.writeAsString(content, flush: true);
    final artifact = ExportArtifact(
      id: file.path,
      type: ExportType.poster,
      format: ExportFormat.svg,
      module: request.module,
      title: request.title,
      filePath: file.path,
      metadataPath: '',
      createdAt: DateTime.now(),
      metadata: ExportMetadata({
        'page': 'poster_export',
        'poster': payload.data.toJson(),
        'export_policy': request.policy?.toJson(),
      }),
    );
    await archive.recordArtifact(artifact);
    return ExportResult(
      request: request,
      artifacts: [artifact],
      message: 'poster svg exported',
    );
  }
}
