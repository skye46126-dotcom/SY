import '../../../services/app_service.dart';
import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_metadata.dart';
import '../domain/export_request.dart';
import '../domain/export_result.dart';
import '../domain/export_type.dart';
import '../infrastructure/export_archive_service.dart';

class DataPackageExportBuilder {
  const DataPackageExportBuilder({
    required this.service,
    required this.archive,
  });

  final AppService service;
  final ExportArchiveService archive;

  Future<Map<String, int>> previewCounts({
    required String userId,
  }) async {
    final data = await service.previewDataPackageExport(userId: userId);
    if (data == null) {
      return const {};
    }
    return data.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
  }

  Future<ExportResult> build(ExportRequest request) async {
    final payload = request.dataPackage;
    if (payload == null) {
      throw StateError('data package export request missing payload');
    }
    final moduleDirectory =
        await archive.preferredModuleDirectoryPath(request.module);
    final result = await service.exportDataPackage(
      userId: payload.userId,
      format: request.format.key,
      outputDirectoryPath: moduleDirectory,
      title: request.title,
      module: request.module,
    );
    if (result == null) {
      throw StateError('export_data_package returned invalid payload');
    }
    final artifacts = _parseArtifacts(result);
    for (final artifact in artifacts) {
      await archive.recordArtifact(artifact);
    }
    return ExportResult(
      request: request,
      artifacts: artifacts,
      message: result['message']?.toString() ?? 'data package exported',
    );
  }

  List<ExportArtifact> _parseArtifacts(Map<String, Object?> result) {
    final rawArtifacts = result['artifacts'];
    if (rawArtifacts is! List) {
      throw StateError('export_data_package missing artifacts');
    }
    return rawArtifacts
        .whereType<Map>()
        .map((item) => _parseArtifact(item.cast<String, dynamic>()))
        .toList();
  }

  ExportArtifact _parseArtifact(Map<String, dynamic> item) {
    final metadata =
        ((item['metadata'] as Map?) ?? const {}).cast<String, dynamic>();
    return ExportArtifact(
      id: item['id']?.toString() ?? item['file_path']?.toString() ?? '',
      type: _parseType(item['type']?.toString()),
      format: _parseFormat(item['format']?.toString()),
      module: item['module']?.toString() ?? '',
      title: item['title']?.toString() ?? '',
      filePath: item['file_path']?.toString() ?? '',
      metadataPath: item['metadata_path']?.toString() ?? '',
      previewPath: item['preview_path']?.toString(),
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: ExportMetadata(metadata),
    );
  }

  ExportType _parseType(String? value) {
    switch (value) {
      case 'data_package':
        return ExportType.dataPackage;
      default:
        throw StateError('unsupported export artifact type: $value');
    }
  }

  ExportFormat _parseFormat(String? value) {
    switch (value) {
      case 'json':
        return ExportFormat.json;
      case 'csv':
        return ExportFormat.csv;
      case 'zip':
        return ExportFormat.zip;
      default:
        throw StateError('unsupported data package artifact format: $value');
    }
  }
}
