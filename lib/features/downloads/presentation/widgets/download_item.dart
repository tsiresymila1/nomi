import 'package:flutter/material.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadItem extends StatefulWidget {
  final ModelInfo model;
  final double? progress;
  final bool isInstalled;
  final bool canRemove;
  final bool canDeleteDownloadedFile;
  final VoidCallback onDownload;
  final VoidCallback onRemove;
  final VoidCallback onCancelDownload;
  final VoidCallback onDeleteDownloadedFile;
  final VoidCallback onEdit;

  const DownloadItem({
    super.key,
    required this.model,
    required this.progress,
    required this.isInstalled,
    required this.canRemove,
    required this.canDeleteDownloadedFile,
    required this.onDownload,
    required this.onRemove,
    required this.onCancelDownload,
    required this.onDeleteDownloadedFile,
    required this.onEdit,
  });

  @override
  State<DownloadItem> createState() => _DownloadItemState();
}

class _DownloadItemState extends State<DownloadItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final progress = widget.progress;
    final isDownloading = progress != null && progress < 1.0;
    final isRemote = model.provider == ModelProviderType.remote;
    final isNetworkSource =
        model.sourceType == 'network' ||
        model.source.startsWith('http://') ||
        model.source.startsWith('https://');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCpu,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            model.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            model.description,
                            maxLines: _expanded ? 4 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(
                      context,
                      isDownloading: isDownloading,
                      progress: progress,
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _capabilityChip(
                          context,
                          label: 'Type: ${model.modelType}',
                          enabled: true,
                        ),
                        _capabilityChip(
                          context,
                          label: 'Image',
                          enabled: model.supportImage,
                        ),
                        _capabilityChip(
                          context,
                          label: 'Audio',
                          enabled: model.supportAudio,
                        ),
                        _capabilityChip(
                          context,
                          label: 'Functions',
                          enabled: model.supportsFunctionCalls,
                        ),
                        _capabilityChip(
                          context,
                          label: 'Thinking',
                          enabled: model.isThinking,
                        ),
                      ],
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(value: progress),
                          ),
                          IconButton(
                            tooltip: 'Cancel download',
                            onPressed: widget.onCancelDownload,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: isDownloading
                              ? null
                              : isRemote
                              ? null
                              : widget.isInstalled
                              ? null
                              : widget.onDownload,
                          icon: isRemote
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedCloudDownload,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : isNetworkSource
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedDownload01,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const HugeIcon(
                                  icon: HugeIcons.strokeRoundedComputerAdd,
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Delete downloaded file',
                          onPressed:
                              widget.canDeleteDownloadedFile && !isDownloading
                              ? () => _confirmDeleteDownloadedFile(context)
                              : null,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isDownloading) const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: widget.canRemove
                              ? 'Remove model'
                              : 'Static default model',
                          onPressed: !widget.canRemove || isDownloading
                              ? null
                              : () => _confirmRemove(context),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(
    BuildContext context, {
    required bool isDownloading,
    required double? progress,
  }) {
    if (isDownloading) {
      return SizedBox(
        width: 50,
        child: Text(
          '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }
    if (widget.isInstalled) {
      return const HugeIcon(
        icon: HugeIcons.strokeRoundedCheckmarkCircle03,
        color: Colors.green,
        size: 18,
      );
    }

    return Text(
      'Not installed',
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final shouldRemove = await showConfirmActionSheet(
      context,
      title: 'Remove Model',
      message: 'Remove "${widget.model.name}" from your device and database?',
      confirmLabel: 'Remove',
    );

    if (shouldRemove) {
      widget.onRemove();
    }
  }

  Future<void> _confirmDeleteDownloadedFile(BuildContext context) async {
    final shouldDelete = await showConfirmActionSheet(
      context,
      title: 'Delete Downloaded File',
      message:
          'Delete downloaded file for "${widget.model.name}"? The model entry will stay in your list.',
      confirmLabel: 'Delete',
    );

    if (shouldDelete) {
      widget.onDeleteDownloadedFile();
    }
  }

  Widget _capabilityChip(
    BuildContext context, {
    required String label,
    required bool enabled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        enabled ? label : '$label: No',
        style: TextStyle(
          fontSize: 11,
          color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
