import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/image_export_service.dart';
import 'safe_pop.dart';

Future<void> showExportDocumentDialog(
  BuildContext context,
  ExportedImageDocument result, {
  Future<void> Function()? onDelete,
}) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final metadataJson =
      const JsonEncoder.withIndent('  ').convert(result.toPayload());
  return showDialog<void>(
    context: rootContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('图片文档'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.title),
              const SizedBox(height: 16),
              if (result.hasPreviewFile)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(
                        File(result.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PreviewFallback(),
                      ),
                    ),
                  ),
                )
              else
                const _PreviewFallback(),
              const SizedBox(height: 16),
              const Text('图片文件'),
              const SizedBox(height: 6),
              SelectableText(result.imagePath),
              const SizedBox(height: 14),
              const Text('元数据文件'),
              const SizedBox(height: 6),
              SelectableText(result.metadataPath),
              const SizedBox(height: 14),
              const Text('导出目录'),
              const SizedBox(height: 6),
              SelectableText(result.directoryPath),
              const SizedBox(height: 14),
              const Text('元数据内容'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E8F2)),
                ),
                child: SelectableText(
                  metadataJson,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (onDelete != null)
          TextButton(
            onPressed: () async {
              await onDelete();
              if (!dialogContext.mounted) return;
              safePop<void>(dialogContext);
            },
            child: const Text('删除导出'),
          ),
        TextButton(
          onPressed: () => safePop<void>(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: const Center(
        child: Text('当前无法预览图片文件'),
      ),
    );
  }
}
