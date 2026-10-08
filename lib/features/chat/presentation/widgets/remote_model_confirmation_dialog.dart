import 'package:flutter/material.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

Future<bool> showRemoteModelConfirmationDialog({
  required BuildContext context,
  required ModelInfo model,
}) => showRemoteDataConfirmationDialog(
  context: context,
  modelName: model.name,
  providerLabel: remoteProviderLabel(model),
);

Future<bool> showRemoteDataConfirmationDialog({
  required BuildContext context,
  required String modelName,
  required String providerLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.cloud_outlined),
      title: const Text('Switch to a remote model?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(modelName, style: Theme.of(dialogContext).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Provider: $providerLabel',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'If you continue, your prompt and the conversation context needed '
            'for the answer will leave this device. Attached files, images, '
            'RAG excerpts, and tool results may also be sent when included in '
            'the request.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Nomi will not switch or send anything until you confirm.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('keep-local-model-button'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay local'),
        ),
        FilledButton.icon(
          key: const ValueKey('confirm-remote-model-button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.cloud_done_outlined, size: 18),
          label: const Text('Continue remotely'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String remoteProviderLabel(ModelInfo model) {
  final apiHost = Uri.tryParse(model.apiUrl ?? '')?.host.trim();
  if (apiHost != null && apiHost.isNotEmpty) return apiHost;

  final source = Uri.tryParse(model.source);
  if (source?.scheme == 'remote-server' && source!.host.isNotEmpty) {
    return 'Remote server ${source.host}';
  }
  return 'Configured remote API';
}
