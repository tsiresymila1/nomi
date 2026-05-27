import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_entry.dart';
import 'package:gena/features/remote_servers/data/providers/remote_server_providers.dart';
import 'package:gena/presentation/widgets/field_wrapper.dart';
import 'package:hugeicons/hugeicons.dart';

class RemoteServersPage extends ConsumerStatefulWidget {
  const RemoteServersPage({super.key});

  @override
  ConsumerState<RemoteServersPage> createState() => _RemoteServersPageState();
}

class _RemoteServersPageState extends ConsumerState<RemoteServersPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(remoteServersControllerProvider);
    final modelsAsync = ref.watch(modelRepositoryProvider);

    final modelCountByServer = <String, int>{};
    final models = modelsAsync.asData?.value ?? const [];
    const sourcePrefix = 'remote-server://';
    for (final model in models) {
      if (!model.source.startsWith(sourcePrefix)) continue;
      final withoutPrefix = model.source.substring(sourcePrefix.length);
      final slashIndex = withoutPrefix.indexOf('/');
      if (slashIndex <= 0) continue;
      final serverId = withoutPrefix.substring(0, slashIndex);
      if (serverId.trim().isEmpty) continue;
      modelCountByServer[serverId] = (modelCountByServer[serverId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Remote Servers',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync all remote models',
            onPressed: _busy
                ? null
                : () => _run('Syncing remote models...', () async {
                    final synced = await ref
                        .read(remoteServersControllerProvider.notifier)
                        .syncAllServers();
                    await AppToast.show(
                      'Synced $synced remote model(s).',
                      type: AppToastType.success,
                    );
                  }),
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Scan local network',
            onPressed: _busy
                ? null
                : () => _run('Scanning local network...', () async {
                    final synced = await ref
                        .read(remoteServersControllerProvider.notifier)
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
        onPressed: _busy ? null : () => _showAddOrEditServerSheet(context),
        child: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
      ),
      body: Stack(
        children: [
          serversAsync.when(
            data: (servers) {
              if (servers.isEmpty) {
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
                itemCount: servers.length,
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final modelCount = modelCountByServer[server.id] ?? 0;
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _ModeBadge(auto: server.autoDiscovered),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                server.baseUrl,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Available models: $modelCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (server.lastSeenAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Last seen: ${server.lastSeenAt!.toLocal()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _testServer(server),
                                    icon: const Icon(
                                      Icons.health_and_safety_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Test'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _busy
                                        ? null
                                        : () => _syncServer(server),
                                    icon: const Icon(Icons.sync, size: 16),
                                    label: const Text('Sync Models'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _showAddOrEditServerSheet(
                                            context,
                                            existing: server,
                                          ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Edit'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _confirmDelete(server),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 240.ms, delay: (index * 25).ms)
                      .slideY(begin: 0.04, end: 0);
                },
              );
            },
            loading: () => Center(
              child: SizedBox(
                width: 40,
                height: 18,
                child: SpinKitThreeBounce(
                  size: 18,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load remote servers: $error'),
              ),
            ),
          ),
          if (_busy)
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
  }

  Future<void> _showAddOrEditServerSheet(
    BuildContext context, {
    RemoteServerEntry? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.baseUrl ?? '');
    final tokenController = TextEditingController(text: existing?.token ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        reverseDuration: Duration(milliseconds: 200),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            20,
            28 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Remote Server' : 'Edit Remote Server',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              FieldWrapper(
                label: 'Server name',
                field: _buildBorderlessField(
                  controller: nameController,
                  hintText: 'My remote server',
                  obscureText: false,
                ),
              ),
              const SizedBox(height: 8),
              FieldWrapper(
                label: 'Base URL',
                field: _buildBorderlessField(
                  controller: urlController,
                  hintText: 'http://192.168.1.30:11434',
                  obscureText: false,
                ),
              ),
              const SizedBox(height: 8),
              FieldWrapper(
                label: 'Token (optional)',
                field: _buildBorderlessField(
                  controller: tokenController,
                  hintText: 'Bearer token',
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final url = urlController.text.trim();
                    final token = tokenController.text.trim();

                    if (name.isEmpty || url.isEmpty) {
                      await AppToast.show(
                        'Server name and URL are required.',
                        type: AppToastType.error,
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _run('Saving server...', () async {
                      final controller = ref.read(
                        remoteServersControllerProvider.notifier,
                      );
                      await controller.addOrUpdateManualServer(
                        id: existing?.id,
                        name: name,
                        baseUrl: url,
                        token: token,
                      );
                      final synced = await controller.syncAllServers();
                      await AppToast.show(
                        existing == null
                            ? 'Remote server added. Synced $synced model(s).'
                            : 'Remote server updated. Synced $synced model(s).',
                        type: AppToastType.success,
                      );
                    });
                  },
                  child: Text(
                    existing == null ? 'Add Server' : 'Update Server',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    urlController.dispose();
    tokenController.dispose();
  }

  Future<void> _testServer(RemoteServerEntry entry) async {
    await _run('Testing ${entry.name}...', () async {
      final result = await ref
          .read(remoteServersControllerProvider.notifier)
          .testConnection(entry);

      final toastType = result.success
          ? AppToastType.success
          : AppToastType.error;
      await AppToast.show(result.message, type: toastType);
    });
  }

  Future<void> _syncServer(RemoteServerEntry entry) async {
    await _run('Syncing ${entry.name}...', () async {
      final synced = await ref
          .read(remoteServersControllerProvider.notifier)
          .syncModelsForServer(entry);
      await AppToast.show(
        'Synced $synced model(s) from ${entry.name}.',
        type: AppToastType.success,
      );
    });
  }

  Future<void> _confirmDelete(RemoteServerEntry entry) async {
    final confirmed = await showConfirmActionSheet(
      context,
      title: 'Delete Remote Server',
      message: 'Delete ${entry.name} and remove its synced models?',
      confirmLabel: 'Delete',
    );

    if (!confirmed) return;

    await _run('Deleting ${entry.name}...', () async {
      await ref
          .read(remoteServersControllerProvider.notifier)
          .removeServer(entry);
      await AppToast.show('Remote server deleted.', type: AppToastType.success);
    });
  }

  Future<void> _run(String label, Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      await AppToast.show('$label failed: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildBorderlessField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: false,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.auto});

  final bool auto;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = auto ? 'Auto' : 'Manual';
    final bg = auto
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
