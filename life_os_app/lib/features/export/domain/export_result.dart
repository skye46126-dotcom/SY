import 'export_artifact.dart';
import 'export_request.dart';

class ExportResult {
  const ExportResult({
    required this.request,
    required this.artifacts,
    required this.message,
  });

  final ExportRequest request;
  final List<ExportArtifact> artifacts;
  final String message;

  ExportArtifact get primaryArtifact => artifacts.first;
}
