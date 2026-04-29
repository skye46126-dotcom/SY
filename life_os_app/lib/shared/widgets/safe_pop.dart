import 'package:flutter/material.dart';

void safePop<T>(BuildContext context, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.pop<T>(result);
  });
}
