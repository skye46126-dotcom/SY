import 'app_service.dart';
import 'native_share_panel.dart';

class ShareTarget {
  const ShareTarget({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.title,
    required this.text,
    required this.fileSizeBytes,
  });

  final String filePath;
  final String fileName;
  final String mimeType;
  final String title;
  final String text;
  final int fileSizeBytes;

  factory ShareTarget.fromJson(Map<String, dynamic> json) {
    return ShareTarget(
      filePath: json['file_path'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExportShareService {
  const ExportShareService({
    required this.service,
    this.sharePanel = const NativeSharePanel(),
  });

  final AppService service;
  final NativeSharePanel sharePanel;

  Future<ShareTarget> prepareTarget({
    required String filePath,
    required String title,
    String? mimeType,
    String? text,
  }) async {
    final data = await service.invokeRaw(
      method: 'prepare_share_target',
      payload: {
        'file_path': filePath,
        'title': title,
        'mime_type': mimeType,
        'text': text,
      },
    );
    return ShareTarget.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> shareFile({
    required String filePath,
    required String title,
    String? mimeType,
    String? text,
  }) async {
    final target = await prepareTarget(
      filePath: filePath,
      title: title,
      mimeType: mimeType,
      text: text,
    );
    await sharePanel.shareFile(
      filePath: target.filePath,
      mimeType: target.mimeType,
      title: target.title,
      text: target.text,
    );
  }
}
