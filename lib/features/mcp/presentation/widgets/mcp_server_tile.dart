import 'package:flutter/material.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';

class McpServerTile extends StatelessWidget {
  const McpServerTile({
    required this.server,
    required this.busy,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final McpServer server;
  final bool busy;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
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
                Switch(
                  value: server.enabled,
                  onChanged: busy ? null : onToggleEnabled,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(server.url, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 4),
            Text(
              server.authHeader != null && server.authHeader!.isNotEmpty
                  ? 'Auth header configured'
                  : 'No auth header',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
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
