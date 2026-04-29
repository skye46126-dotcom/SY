import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/export_artifact.dart';
import '../domain/export_format.dart';
import '../domain/export_history_item.dart';
import '../domain/export_metadata.dart';
import '../domain/export_type.dart';

class ExportArchiveService {
  const ExportArchiveService();

  Future<String> preferredExportRootPath() async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return '${downloads.path}/SkyOS/exports';
      }
    }

    final documents = await getApplicationDocumentsDirectory();
    return '${documents.path}/SkyOS/exports';
  }

  Future<String> preferredModuleDirectoryPath(String module) async {
    final root = await preferredExportRootPath();
    return '$root/${_slug(module)}';
  }

  Future<void> recordArtifact(ExportArtifact artifact) async {
    await _ensureMetadataFile(artifact);
    final items = await _readHistory();
    items.removeWhere((item) => _sameArtifact(item, artifact));
    items.insert(0, ExportHistoryItem.fromArtifact(artifact));
    await _writeHistory(items);
  }

  Future<List<ExportHistoryItem>> listHistory({
    ExportType? type,
    String? module,
    int limit = 100,
  }) async {
    final items = await _readHistory();
    final filtered = items
        .where((item) => type == null || item.type == type)
        .where((item) => module == null || item.module == _slug(module))
        .where((item) => File(item.filePath).existsSync())
        .where((item) =>
            item.metadataPath.isEmpty || File(item.metadataPath).existsSync())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (filtered.length != items.length) {
      await _writeHistory(filtered);
    }
    return filtered.take(limit).toList();
  }

  Future<void> deleteHistoryItem(ExportHistoryItem item) async {
    final file = File(item.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    if (item.metadataPath.isNotEmpty) {
      final metadata = File(item.metadataPath);
      if (await metadata.exists()) {
        await metadata.delete();
      }
    }
    final items = await _readHistory();
    items.removeWhere((element) => _sameHistoryItem(element, item));
    await _writeHistory(items);
  }

  bool _sameArtifact(ExportHistoryItem item, ExportArtifact artifact) {
    if (item.metadataPath.isNotEmpty && artifact.metadataPath.isNotEmpty) {
      return item.metadataPath == artifact.metadataPath;
    }
    return item.filePath == artifact.filePath || item.id == artifact.id;
  }

  bool _sameHistoryItem(ExportHistoryItem left, ExportHistoryItem right) {
    if (left.metadataPath.isNotEmpty && right.metadataPath.isNotEmpty) {
      return left.metadataPath == right.metadataPath;
    }
    return left.filePath == right.filePath || left.id == right.id;
  }

  Future<File> _resolveIndexFile() async {
    final root = Directory(await preferredExportRootPath());
    await root.create(recursive: true);
    return File('${root.path}/export_index.json');
  }

  Future<void> _ensureMetadataFile(ExportArtifact artifact) async {
    if (artifact.metadataPath.isEmpty) return;
    final file = File(artifact.metadataPath);
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    final payload = {
      'id': artifact.id,
      'type': artifact.type.key,
      'format': artifact.format.key,
      'module': artifact.module,
      'title': artifact.title,
      'file_path': artifact.filePath,
      'metadata_path': artifact.metadataPath,
      'preview_path': artifact.previewPath,
      'created_at': artifact.createdAt.toIso8601String(),
      'metadata': artifact.metadata.toJson(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<List<ExportHistoryItem>> _readHistory() async {
    final file = await _resolveIndexFile();
    if (!await file.exists()) {
      return <ExportHistoryItem>[];
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : const [];
      return list
          .whereType<Map>()
          .map((item) => _fromPayload(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <ExportHistoryItem>[];
    }
  }

  Future<void> _writeHistory(List<ExportHistoryItem> items) async {
    final file = await _resolveIndexFile();
    final payload = items.map(_toPayload).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  ExportHistoryItem _fromPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('file_path')) {
      return ExportHistoryItem(
        id: payload['id']?.toString() ?? '',
        type: _parseType(payload['type']?.toString()),
        format: _parseFormat(payload['format']?.toString()),
        module: payload['module']?.toString() ?? '',
        title: payload['title']?.toString() ?? '',
        filePath: payload['file_path']?.toString() ?? '',
        metadataPath: payload['metadata_path']?.toString() ?? '',
        previewPath: payload['preview_path']?.toString(),
        createdAt: DateTime.tryParse(payload['created_at']?.toString() ?? '') ??
            DateTime(1970),
        metadata: ExportMetadata(
          ((payload['metadata'] as Map?) ?? const {}).cast<String, dynamic>(),
        ),
      );
    }

    final module = payload['module']?.toString() ?? '';
    final imagePath = payload['image_path']?.toString() ?? '';
    final metadata = Map<String, dynamic>.from(payload)
      ..remove('module')
      ..remove('title')
      ..remove('exported_at')
      ..remove('image_path')
      ..remove('metadata_path')
      ..remove('directory_path');
    return ExportHistoryItem(
      id: payload['metadata_path']?.toString() ?? imagePath,
      type: _inferTypeFromModule(module),
      format: ExportFormat.png,
      module: module,
      title: payload['title']?.toString() ?? '',
      filePath: imagePath,
      metadataPath: payload['metadata_path']?.toString() ?? '',
      previewPath: imagePath,
      createdAt: DateTime.tryParse(payload['exported_at']?.toString() ?? '') ??
          DateTime(1970),
      metadata: ExportMetadata(metadata),
    );
  }

  Map<String, dynamic> _toPayload(ExportHistoryItem item) {
    return {
      'id': item.id,
      'type': item.type.key,
      'format': item.format.key,
      'module': item.module,
      'title': item.title,
      'file_path': item.filePath,
      'metadata_path': item.metadataPath,
      'preview_path': item.previewPath,
      'created_at': item.createdAt.toIso8601String(),
      'metadata': item.metadata.toJson(),
    };
  }

  ExportType _parseType(String? value) {
    switch (value) {
      case 'backup':
        return ExportType.backup;
      case 'data_package':
        return ExportType.dataPackage;
      case 'report':
        return ExportType.report;
      case 'snapshot':
        return ExportType.snapshot;
      case 'poster':
        return ExportType.poster;
      default:
        return _inferTypeFromModule(value);
    }
  }

  ExportFormat _parseFormat(String? value) {
    switch (value) {
      case 'sqlite':
        return ExportFormat.sqlite;
      case 'json':
        return ExportFormat.json;
      case 'csv':
        return ExportFormat.csv;
      case 'zip':
        return ExportFormat.zip;
      case 'markdown':
        return ExportFormat.markdown;
      case 'txt':
        return ExportFormat.txt;
      case 'pdf':
        return ExportFormat.pdf;
      case 'png':
        return ExportFormat.png;
      case 'svg':
        return ExportFormat.svg;
      default:
        return ExportFormat.png;
    }
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  ExportType _inferTypeFromModule(String? module) {
    switch (module) {
      case 'poster':
        return ExportType.poster;
      case 'data_package':
        return ExportType.dataPackage;
      case 'report':
        return ExportType.report;
      case 'today':
      case 'review':
      case 'project':
      case 'cost':
      case 'day_detail':
        return ExportType.snapshot;
      case 'backup':
        return ExportType.backup;
      default:
        return ExportType.snapshot;
    }
  }
}
