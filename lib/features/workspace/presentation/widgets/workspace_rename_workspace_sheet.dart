import 'package:flutter/material.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class WorkspaceRenameWorkspaceSheet extends StatelessWidget {
  const WorkspaceRenameWorkspaceSheet({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rename workspace',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          FieldWrapper(
            label: 'Name',
            field: TextField(
              controller: controller,
              maxLength: 64,
              decoration: const InputDecoration(hintText: 'My workspace'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
