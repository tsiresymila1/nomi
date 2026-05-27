import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/providers/remote_server_providers.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_tile.dart';

class RemoteServerList extends StatelessWidget {
  const RemoteServerList({
    required this.state,
    required this.modelCountByServer,
    required this.onTest,
    required this.onSync,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final RemoteServersState state;
  final Map<String, int> modelCountByServer;
  final Future<void> Function(RemoteServerEntry server) onTest;
  final Future<void> Function(RemoteServerEntry server) onSync;
  final Future<void> Function(RemoteServerEntry server) onEdit;
  final Future<void> Function(RemoteServerEntry server) onDelete;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return Center(
        child: SizedBox(
          width: 40,
          height: 18,
          child: SpinKitThreeBounce(
            size: 18,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      );
    }

    if (state.servers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No remote servers yet. Add one manually or scan your network.',
            textAlign: TextAlign.center,
          ),
        ),
      ).animate().fade(duration: 300.ms);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: state.servers.length,
      itemBuilder: (context, index) {
        final server = state.servers[index];
        return RemoteServerTile(
              server: server,
              modelCount: modelCountByServer[server.id] ?? 0,
              busy: state.busy,
              onTest: () => onTest(server),
              onSync: () => onSync(server),
              onEdit: () => onEdit(server),
              onDelete: () => onDelete(server),
            )
            .animate()
            .fadeIn(duration: 240.ms, delay: (index * 25).ms)
            .slideY(begin: 0.04, end: 0);
      },
    );
  }
}
