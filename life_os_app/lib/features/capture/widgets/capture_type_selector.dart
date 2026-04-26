import 'package:flutter/material.dart';

import '../capture_controller.dart';
import '../../../shared/widgets/segmented_control.dart';

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
    return SegmentedControl<CaptureType>(
      value: selectedType,
      onChanged: onChanged,
      options: [
        for (final type in CaptureType.values)
          SegmentedControlOption(
            value: type,
            label: type.label,
          ),
      ],
    );
  }
}
