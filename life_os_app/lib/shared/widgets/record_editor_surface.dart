import 'package:flutter/material.dart';

class RecordEditorSurface extends StatelessWidget {
  const RecordEditorSurface({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onCancel,
    required this.onSave,
    this.cancelLabel = '取消',
    this.saveLabel = '保存',
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String cancelLabel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FD),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onCancel,
                    tooltip: cancelLabel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      child: Text(saveLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
