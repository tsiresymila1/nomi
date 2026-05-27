import 'package:flutter/material.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_mode_badge.dart';

class RemoteServerTile extends StatelessWidget {
  const RemoteServerTile({
    required this.server,
    required this.modelCount,
    required this.busy,
    required this.onTest,
    required this.onSync,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final RemoteServerEntry server;
  final int modelCount;
  final bool busy;
  final VoidCallback onTest;
  final VoidCallback onSync;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    server.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                RemoteServerModeBadge(auto: server.autoDiscovered),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              server.baseUrl,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available models: $modelCount',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (server.lastSeenAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last seen: ${server.lastSeenAt!.toLocal()}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onTest,
                  icon: const Icon(Icons.health_and_safety_outlined, size: 16),
                  label: const Text('Test'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onSync,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync Models'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
