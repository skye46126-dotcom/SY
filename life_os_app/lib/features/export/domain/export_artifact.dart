import 'export_format.dart';
import 'export_metadata.dart';
import 'export_type.dart';

class ExportArtifact {
  const ExportArtifact({
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
}
