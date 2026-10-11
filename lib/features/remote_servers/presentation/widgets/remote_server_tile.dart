import 'package:flutter/material.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_mode_badge.dart';

enum _RemoteServerAction { test, edit, delete }

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
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        leading: const Icon(Icons.dns_outlined),
        title: Row(
          children: [
            Expanded(
              child: Text(
                server.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            RemoteServerModeBadge(auto: server.autoDiscovered),
          ],
        ),
        subtitle: Text(
          '${server.protocol.label} · $modelCount model${modelCount == 1 ? '' : 's'}\n${server.baseUrl}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                key: const ValueKey('remote-server-sync'),
                tooltip: 'Sync models',
                onPressed: onSync,
                icon: const Icon(Icons.sync_rounded),
              ),
            PopupMenuButton<_RemoteServerAction>(
              key: const ValueKey('remote-server-more-actions'),
              tooltip: 'More server actions',
              enabled: !busy,
              onSelected: (action) {
                switch (action) {
                  case _RemoteServerAction.test:
                    onTest();
                  case _RemoteServerAction.edit:
                    onEdit();
                  case _RemoteServerAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _RemoteServerAction.test,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.health_and_safety_outlined),
                    title: Text('Test connection'),
                  ),
                ),
                PopupMenuItem(
                  value: _RemoteServerAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit server'),
                  ),
                ),
                PopupMenuItem(
                  value: _RemoteServerAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete server'),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
