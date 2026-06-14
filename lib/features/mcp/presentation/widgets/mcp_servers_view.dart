import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';
import 'package:gena/features/mcp/presentation/cubit/mcp_servers_cubit.dart';
import 'package:gena/features/mcp/presentation/widgets/mcp_server_form_sheet.dart';
import 'package:gena/features/mcp/presentation/widgets/mcp_server_tile.dart';
import 'package:hugeicons/hugeicons.dart';

class McpServersView extends StatelessWidget {
  const McpServersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<McpServersCubit, McpServersState>(
      builder: (context, state) {
        final cubit = context.read<McpServersCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'MCP Servers',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            mini: true,
            onPressed: state.busy ? null : () => _showServerSheet(context),
            child: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          ),
          body: Stack(
            children: [
              if (state.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.servers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No MCP servers yet. Add a Streamable HTTP MCP server to '
                      'expose its tools to the chat model.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.servers.length,
                  itemBuilder: (context, index) {
                    final server = state.servers[index];
                    return McpServerTile(
                      server: server,
                      busy: state.busy,
                      onToggleEnabled: (enabled) => _run(
                        context,
                        () => cubit.setEnabled(server, enabled),
                      ),
                      onEdit: () => _showServerSheet(context, existing: server),
                      onDelete: () => _confirmDelete(context, server),
                    );
                  },
                ),
              if (state.busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.07),
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 18,
                        child: SpinKitThreeBounce(
                          size: 18,
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showServerSheet(
    BuildContext context, {
    McpServer? existing,
  }) async {
    final cubit = context.read<McpServersCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return McpServerFormSheet(
          existing: existing,
          onSubmit: (name, url, authHeader, enabled) async {
            await _run(context, () async {
              await cubit.addOrUpdateServer(
                id: existing?.id,
                name: name,
                url: url,
                authHeader: authHeader,
                enabled: enabled,
              );
              await AppToast.show(
                existing == null ? 'MCP server added.' : 'MCP server updated.',
                type: AppToastType.success,
              );
            });
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, McpServer server) async {
    final confirmed = await showConfirmActionSheet(
      context,
      title: 'Delete MCP Server',
      message: 'Delete ${server.name}?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    await _run(context, () async {
      await context.read<McpServersCubit>().removeServer(server);
      await AppToast.show('MCP server deleted.', type: AppToastType.success);
    });
  }

  Future<void> _run(BuildContext context, Future<void> Function() task) {
    return context.read<McpServersCubit>().runBusyTask(task);
  }
}
