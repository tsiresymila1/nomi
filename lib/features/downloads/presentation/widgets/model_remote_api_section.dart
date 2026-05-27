import 'package:flutter/material.dart';
import 'package:gena/features/chat/presentation/widgets/model_settings_number_field.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class ModelRemoteApiSection extends StatelessWidget {
  final TextEditingController apiUrlController;
  final TextEditingController apiTokenController;
  final TextEditingController maxTokensController;
  final TextEditingController outputTokensController;

  const ModelRemoteApiSection({
    super.key,
    required this.apiUrlController,
    required this.apiTokenController,
    required this.maxTokensController,
    required this.outputTokensController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldWrapper(
          label: 'API URL',
          field: TextField(
            controller: apiUrlController,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com/v1',
            ),
          ),
        ),
        FieldWrapper(
          label: 'API Token',
          field: TextField(
            controller: apiTokenController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Bearer token'),
          ),
        ),
        ModelSettingsNumberField(
          controller: maxTokensController,
          label: 'Max tokens (context, up to 1,000,000)',
        ),
        const SizedBox(height: 8),
        ModelSettingsNumberField(
          controller: outputTokensController,
          label: 'Output tokens',
        ),
      ],
    );
  }
}
