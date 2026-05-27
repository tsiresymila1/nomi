import 'package:flutter/material.dart';
import 'package:gena/core/widgets/confirm_action_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item_actions.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item_capability_chip.dart';
import 'package:gena/features/downloads/presentation/widgets/download_item_status_badge.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadItem extends StatefulWidget {
  const DownloadItem({
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
    super.key,
  });

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
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
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
                        children: [
                          Text(
                            model.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                    DownloadItemStatusBadge(
                      isDownloading: isDownloading,
                      progress: progress,
                      isInstalled: widget.isInstalled,
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
                        DownloadItemCapabilityChip(
                          label: 'Type: ${model.modelType}',
                          enabled: true,
                        ),
                        DownloadItemCapabilityChip(
                          label: 'Image',
                          enabled: model.supportImage,
                        ),
                        DownloadItemCapabilityChip(
                          label: 'Audio',
                          enabled: model.supportAudio,
                        ),
                        DownloadItemCapabilityChip(
                          label: 'Functions',
                          enabled: model.supportsFunctionCalls,
                        ),
                        DownloadItemCapabilityChip(
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
                    DownloadItemActions(
                      isDownloading: isDownloading,
                      isRemote: isRemote,
                      isNetworkSource: isNetworkSource,
                      canRemove: widget.canRemove,
                      canDeleteDownloadedFile: widget.canDeleteDownloadedFile,
                      isInstalled: widget.isInstalled,
                      onEdit: widget.onEdit,
                      onDownload: widget.onDownload,
                      onRemove: () => _confirmRemove(context),
                      onDeleteDownloadedFile: () {
                        _confirmDeleteDownloadedFile(context);
                      },
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

  Future<void> _confirmRemove(BuildContext context) async {
    final shouldRemove = await showConfirmActionSheet(
      context,
      title: 'Remove Model',
      message: 'Remove "${widget.model.name}" from your device and database?',
      confirmLabel: 'Remove',
    );
    if (shouldRemove) widget.onRemove();
  }

  Future<void> _confirmDeleteDownloadedFile(BuildContext context) async {
    final shouldDelete = await showConfirmActionSheet(
      context,
      title: 'Delete Downloaded File',
      message:
          'Delete downloaded file for "${widget.model.name}"? The model entry will stay in your list.',
      confirmLabel: 'Delete',
    );
    if (shouldDelete) widget.onDeleteDownloadedFile();
  }
}
