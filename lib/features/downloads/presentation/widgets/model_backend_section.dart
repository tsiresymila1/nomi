import 'package:flutter/material.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class ModelBackendSection extends StatelessWidget {
  final String preferredBackend;
  final ValueChanged<String> onBackendChanged;

  const ModelBackendSection({
    super.key,
    required this.preferredBackend,
    required this.onBackendChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FieldWrapper(
      label: 'Preferred backend',
      field: DropdownButtonFormField<String>(
        initialValue: preferredBackend,
        style: TextStyle(fontSize: 14),
        decoration: const InputDecoration(hintText: 'Preferred backend'),
        items: const [
          DropdownMenuItem(value: 'auto', child: Text('Auto')),
          DropdownMenuItem(value: 'gpu', child: Text('GPU')),
          DropdownMenuItem(value: 'cpu', child: Text('CPU')),
          DropdownMenuItem(value: 'npu', child: Text('NPU')),
        ],
        onChanged: (value) {
          if (value != null) onBackendChanged(value);
        },
      ),
    );
  }
}
