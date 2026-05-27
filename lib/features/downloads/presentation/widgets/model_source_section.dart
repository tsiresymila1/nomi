import 'package:flutter/material.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';

class ModelSourceSection extends StatelessWidget {
  final String sourceType;
  final String providerType;
  final TextEditingController sourceController;
  final bool picking;
  final ValueChanged<String> onSourceTypeChanged;
  final VoidCallback onPickFile;

  const ModelSourceSection({
    super.key,
    required this.sourceType,
    required this.providerType,
    required this.sourceController,
    required this.picking,
    required this.onSourceTypeChanged,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    if (providerType != 'local') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'network', label: Text('URL')),
            ButtonSegment<String>(value: 'file', label: Text('File')),
          ],
          selected: {sourceType},
          onSelectionChanged: (value) {
            onSourceTypeChanged(value.first);
            sourceController.clear();
          },
        ),
        const SizedBox(height: 8),
        if (sourceType == 'file')
          FilledButton.icon(
            onPressed: picking ? null : onPickFile,
            icon: picking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: const Text('Choose file'),
          ),
        if (sourceType == 'file') const SizedBox(height: 8),
        FieldWrapper(
          label: sourceType == 'network' ? 'URL source' : 'File path',
          field: TextField(
            controller: sourceController,
            decoration: InputDecoration(
              hintText: sourceType == 'network'
                  ? 'https://...'
                  : '/absolute/path/model.task',
            ),
          ),
        ),
      ],
    );
  }
}
