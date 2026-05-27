import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/providers/remote_server_providers.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_form_sheet.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_server_list.dart';
import 'package:hugeicons/hugeicons.dart';

class RemoteServersView extends StatelessWidget {
  const RemoteServersView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: sl<ModelRepository>().watchModels(),
      builder: (context, modelsSnapshot) {
        final modelCountByServer = <String, int>{};
        final models = modelsSnapshot.data ?? const [];
        const sourcePrefix = 'remote-server://';
        for (final model in models) {
          if (!model.source.startsWith(sourcePrefix)) continue;
          final withoutPrefix = model.source.substring(sourcePrefix.length);
          final slashIndex = withoutPrefix.indexOf('/');
          if (slashIndex <= 0) continue;
          final serverId = withoutPrefix.substring(0, slashIndex).trim();
          if (serverId.isEmpty) continue;
          modelCountByServer[serverId] =
              (modelCountByServer[serverId] ?? 0) + 1;
        }

        return BlocBuilder<RemoteServersCubit, RemoteServersState>(
          builder: (context, state) {
            final cubit = context.read<RemoteServersCubit>();
            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Remote Servers',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Sync all remote models',
                    onPressed: state.busy
                        ? null
                        : () => _run(context, () async {
                            final synced = await cubit.syncAllServers();
                            await AppToast.show(
                              'Synced $synced remote model(s).',
                              type: AppToastType.success,
                            );
                          }),
                    icon: const Icon(Icons.sync_rounded),
                  ),
                  IconButton(
                    tooltip: 'Scan local network',
                    onPressed: state.busy
                        ? null
                        : () => _run(context, () async {
                            final synced = await cubit
                                .scanNetworkAndAutoManageServers();
                            await AppToast.show(
                              'Network scan completed. Synced $synced model(s).',
                              type: AppToastType.success,
                            );
                          }),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedRadar02),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                mini: true,
                onPressed: state.busy ? null : () => _showServerSheet(context),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
              ),
              body: Stack(
                children: [
                  RemoteServerList(
                    state: state,
                    modelCountByServer: modelCountByServer,
                    onTest: (server) => _run(context, () async {
                      final result = await cubit.testConnection(server);
                      await AppToast.show(
                        result.message,
                        type: result.success
                            ? AppToastType.success
                            : AppToastType.error,
                      );
                    }),
                    onSync: (server) => _run(context, () async {
                      final synced = await cubit.syncModelsForServer(server);
                      await AppToast.show(
                        'Synced $synced model(s) from ${server.name}.',
                        type: AppToastType.success,
                      );
                    }),
                    onEdit: (server) =>
                        _showServerSheet(context, existing: server),
                    onDelete: (server) => _confirmDelete(context, server),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
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
      },
    );
  }

  Future<void> _showServerSheet(
    BuildContext context, {
    RemoteServerEntry? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return RemoteServerFormSheet(
          existing: existing,
          onSubmit: (name, baseUrl, token) async {
            final cubit = context.read<RemoteServersCubit>();
            await _run(context, () async {
              await cubit.addOrUpdateManualServer(
                id: existing?.id,
                name: name,
                baseUrl: baseUrl,
                token: token,
              );
              final synced = await cubit.syncAllServers();
              await AppToast.show(
                existing == null
                    ? 'Remote server added. Synced $synced model(s).'
                    : 'Remote server updated. Synced $synced model(s).',
                type: AppToastType.success,
              );
            });
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RemoteServerEntry entry,
  ) async {
    final confirmed = await showConfirmActionSheet(
      context,
      title: 'Delete Remote Server',
      message: 'Delete ${entry.name} and remove its synced models?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    await _run(context, () async {
      await context.read<RemoteServersCubit>().removeServer(entry);
      await AppToast.show('Remote server deleted.', type: AppToastType.success);
    });
  }

  Future<void> _run(BuildContext context, Future<void> Function() task) {
    return context.read<RemoteServersCubit>().runBusyTask(task);
  }
}
