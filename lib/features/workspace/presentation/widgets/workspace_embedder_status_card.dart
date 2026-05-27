import 'package:flutter/material.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';

class WorkspaceEmbedderStatusCard extends StatelessWidget {
  const WorkspaceEmbedderStatusCard({
    super.key,
    required this.state,
    required this.onInstallPressed,
  });

  final WorkspaceEmbedderInstallState state;
  final VoidCallback onInstallPressed;

  @override
  Widget build(BuildContext context) {
    final isBusy =
        state.phase == WorkspaceEmbedderInstallPhase.downloading ||
        state.phase == WorkspaceEmbedderInstallPhase.checking;
    final isFailed = state.phase == WorkspaceEmbedderInstallPhase.failed;
    final canInstall =
        state.phase == WorkspaceEmbedderInstallPhase.idle || isFailed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.message,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (isFailed && state.error != null) ...[
            const SizedBox(height: 6),
            Text(
              state.error!,
              style: const TextStyle(fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isBusy ||
              state.modelProgress > 0 ||
              state.tokenizerProgress > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Model: ${state.modelProgress}%',
              style: const TextStyle(fontSize: 11),
            ),
            LinearProgressIndicator(value: state.modelProgress / 100),
            const SizedBox(height: 6),
            Text(
              'Tokenizer: ${state.tokenizerProgress}%',
              style: const TextStyle(fontSize: 11),
            ),
            LinearProgressIndicator(value: state.tokenizerProgress / 100),
          ],
          if (canInstall) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onInstallPressed,
                child: const Text('Install embedder'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
