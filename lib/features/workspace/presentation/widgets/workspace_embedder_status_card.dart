import 'package:flutter/material.dart';
import 'package:gena/features/workspace/data/models/workspace_embedder_install_state.dart';

/// Reports the workspace RAG engine readiness/indexing state.
///
/// The embedding model is bundled with the app and provisioned by
/// `mobile_rag_engine`, so there is no download progress — this card surfaces
/// engine initialization status and lets the user re-check readiness.
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
    final canCheck = !isBusy;

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
          if (isBusy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (canCheck) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onInstallPressed,
                child: const Text('Check RAG engine'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
