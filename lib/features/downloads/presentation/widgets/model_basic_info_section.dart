import 'package:flutter/material.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

const _modelTypes = <String>[
  'general',
  'gemmaIt',
  'gemma4',
  'deepSeek',
  'qwen',
  'qwen3',
  'llama',
  'hammer',
  'functionGemma',
  'phi',
];

class ModelBasicInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String modelType;
  final ValueChanged<String> onModelTypeChanged;

  const ModelBasicInfoSection({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.modelType,
    required this.onModelTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        FieldWrapper(
          label: 'Name',
          field: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
        ),
        FieldWrapper(
          label: "Description",
          field: TextField(
            controller: descriptionController,
            decoration: const InputDecoration(hintText: 'Description'),
          ),
        ),
        FieldWrapper(
          label: 'Model type',
          field: DropdownButtonFormField<String>(
            initialValue: modelType,
            style: TextStyle(fontSize: 14),
            items: _modelTypes
                .map(
                  (type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onModelTypeChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
