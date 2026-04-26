import 'package:flutter/material.dart';

import '../capture_controller.dart';

class CaptureTypeSelector extends StatelessWidget {
  const CaptureTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  final CaptureType selectedType;
  final ValueChanged<CaptureType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final type in CaptureType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: selectedType == type,
            onSelected: (_) => onChanged(type),
          ),
      ],
    );
  }
}
