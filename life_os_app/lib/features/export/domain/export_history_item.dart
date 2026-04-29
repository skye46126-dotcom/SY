import 'export_artifact.dart';
import 'export_format.dart';
import 'export_metadata.dart';
import 'export_type.dart';

class ExportHistoryItem {
  const ExportHistoryItem({
    required this.id,
    required this.type,
    required this.format,
    required this.module,
    required this.title,
    required this.filePath,
    required this.metadataPath,
    required this.createdAt,
    required this.metadata,
    this.previewPath,
  });

  final String id;
  final ExportType type;
  final ExportFormat format;
  final String module;
  final String title;
  final String filePath;
  final String metadataPath;
  final DateTime createdAt;
  final ExportMetadata metadata;
  final String? previewPath;

  factory ExportHistoryItem.fromArtifact(ExportArtifact artifact) {
    return ExportHistoryItem(
      id: artifact.id,
      type: artifact.type,
      format: artifact.format,
      module: artifact.module,
      title: artifact.title,
      filePath: artifact.filePath,
      metadataPath: artifact.metadataPath,
      createdAt: artifact.createdAt,
      metadata: artifact.metadata,
      previewPath: artifact.previewPath,
    );
  }
}
