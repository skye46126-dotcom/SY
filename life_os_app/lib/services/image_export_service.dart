import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

class ExportedImageDocument {
  const ExportedImageDocument({
    required this.module,
    required this.title,
    required this.exportedAt,
    required this.directoryPath,
    required this.imagePath,
    required this.metadataPath,
    required this.metadata,
  });

  final String module;
  final String title;
  final DateTime exportedAt;
  final String directoryPath;
  final String imagePath;
  final String metadataPath;
  final Map<String, dynamic> metadata;

  String get fileName => imagePath.split(Platform.pathSeparator).last;

  bool get hasPreviewFile => File(imagePath).existsSync();

  Map<String, Object?> toPayload() {
    return {
      'module': module,
      'title': title,
      'exported_at': exportedAt.toIso8601String(),
      'image_path': imagePath,
      'metadata_path': metadataPath,
      'directory_path': directoryPath,
      ...metadata,
    };
  }

  factory ExportedImageDocument.fromPayload(Map<String, dynamic> payload) {
    final exportedAtRaw = payload['exported_at']?.toString();
    final metadata = Map<String, dynamic>.from(payload)
      ..remove('module')
      ..remove('title')
      ..remove('exported_at')
      ..remove('image_path')
      ..remove('metadata_path')
      ..remove('directory_path');
    return ExportedImageDocument(
      module: payload['module'] as String? ?? '',
      title: payload['title'] as String? ?? '',
      exportedAt: DateTime.tryParse(exportedAtRaw ?? '') ?? DateTime(1970),
      directoryPath: payload['directory_path'] as String? ?? '',
      imagePath: payload['image_path'] as String? ?? '',
      metadataPath: payload['metadata_path'] as String? ?? '',
      metadata: metadata,
    );
  }
}

class ImageExportService {
  const ImageExportService();

  Future<String> preferredExportDirectoryPath({
    String? module,
  }) async {
    final exportRoot = await _resolveExportRoot();
    if (module == null || module.trim().isEmpty) {
      return exportRoot.path;
    }
    return '${exportRoot.path}/${_slug(module)}';
  }

  Future<ExportedImageDocument> exportBoundary({
    required GlobalKey boundaryKey,
    required String module,
    required String title,
    Map<String, Object?> metadata = const {},
    double? pixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError('导出区域尚未挂载完成。');
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('当前页面未找到可导出的图像边界。');
    }

    final exportedAt = DateTime.now();
    final ratio = pixelRatio ?? _resolvePixelRatio(context);
    await _waitForStableFrame();
    if (!renderObject.attached) {
      throw StateError('导出区域已失效，请返回页面后重试。');
    }
    final image = await renderObject.toImage(pixelRatio: ratio);

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('当前页面无法生成 PNG 图像数据。');
      }

      final moduleDirectory = Directory(
        await preferredExportDirectoryPath(module: module),
      );
      await moduleDirectory.create(recursive: true);

      final baseName = '${_slug(title)}_${_timestamp(exportedAt)}';
      final imageFile = File('${moduleDirectory.path}/$baseName.png');
      await imageFile.writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );

      final metadataFile = File('${moduleDirectory.path}/$baseName.json');
      final payload = <String, Object?>{
        'module': module,
        'title': title,
        'exported_at': exportedAt.toIso8601String(),
        'image_path': imageFile.path,
        'metadata_path': metadataFile.path,
        'directory_path': moduleDirectory.path,
        'pixel_ratio': ratio,
        ...metadata,
      };
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      final document = ExportedImageDocument.fromPayload(
        payload.cast<String, dynamic>(),
      );
      await _upsertExportIndex(document);
      return document;
    } finally {
      image.dispose();
    }
  }

  Future<List<ExportedImageDocument>> listExportedDocuments({
    String? module,
    int limit = 50,
  }) async {
    final indexed = await _readExportIndex();
    final sanitized = indexed
        .where((item) => module == null || item.module == _slug(module))
        .where((item) => File(item.imagePath).existsSync())
        .where((item) => File(item.metadataPath).existsSync())
        .toList()
      ..sort((a, b) => b.exportedAt.compareTo(a.exportedAt));

    if (sanitized.length != indexed.length) {
      await _writeExportIndex(sanitized);
    }

    if (sanitized.isNotEmpty) {
      return sanitized.take(limit).toList();
    }

    return _scanExportDirectory(
      module: module,
      limit: limit,
    );
  }

  Future<void> deleteExportedDocument(ExportedImageDocument document) async {
    final imageFile = File(document.imagePath);
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
    final metadataFile = File(document.metadataPath);
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
    final indexed = await _readExportIndex();
    indexed.removeWhere((item) => item.metadataPath == document.metadataPath);
    await _writeExportIndex(indexed);
  }

  double _resolvePixelRatio(BuildContext context) {
    final view = View.maybeOf(context);
    final devicePixelRatio = view?.devicePixelRatio ?? 2.0;
    return devicePixelRatio.clamp(1.0, 2.2);
  }

  Future<void> _waitForStableFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  Future<Directory> _resolveExportRoot() async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.path}/SkyeOS/exports');
      }
    }

    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/SkyeOS/exports');
  }

  Future<File> _resolveIndexFile() async {
    final root = await _resolveExportRoot();
    await root.create(recursive: true);
    return File('${root.path}/export_index.json');
  }

  Future<List<ExportedImageDocument>> _readExportIndex() async {
    final file = await _resolveIndexFile();
    if (!await file.exists()) {
      return const [];
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      final list = (decoded is List ? decoded : const []);
      return list
          .whereType<Map>()
          .map((item) => ExportedImageDocument.fromPayload(
                item.cast<String, dynamic>(),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeExportIndex(List<ExportedImageDocument> documents) async {
    final file = await _resolveIndexFile();
    final payload = documents.map((item) => item.toPayload()).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<void> _upsertExportIndex(ExportedImageDocument document) async {
    final indexed = await _readExportIndex();
    indexed.removeWhere((item) => item.metadataPath == document.metadataPath);
    indexed.insert(0, document);
    await _writeExportIndex(indexed);
  }

  Future<List<ExportedImageDocument>> _scanExportDirectory({
    String? module,
    int limit = 50,
  }) async {
    final root = Directory(await preferredExportDirectoryPath(module: module));
    if (!await root.exists()) {
      return const [];
    }
    final metadataFiles = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith('.json') &&
          !entity.path.endsWith('export_index.json')) {
        metadataFiles.add(entity);
      }
    }
    final documents = <ExportedImageDocument>[];
    for (final file in metadataFiles) {
      try {
        final payload = jsonDecode(await file.readAsString());
        if (payload is Map) {
          final document = ExportedImageDocument.fromPayload(
              payload.cast<String, dynamic>());
          if (File(document.imagePath).existsSync()) {
            documents.add(document);
          }
        }
      } catch (_) {
        continue;
      }
    }
    documents.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    return documents.take(limit).toList();
  }

  String _slug(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'export' : normalized;
  }

  String _timestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }
}
