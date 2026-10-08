import 'package:flutter/material.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';

class ChatInputAttachmentPreviewList extends StatelessWidget {
  const ChatInputAttachmentPreviewList({
    super.key,
    required this.attachments,
    required this.onRemove,
    this.onAddToWorkspace,
  });

  final List<ChatAttachmentDraft> attachments;
  final ValueChanged<String> onRemove;
  final ValueChanged<PreparedChatAttachment>? onAddToWorkspace;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final draft = attachments[index];
          final attachment = draft.attachment;
          final isDocument = attachment?.kind == ChatAttachmentKind.document;
          final isAudio = attachment?.kind == ChatAttachmentKind.audio;
          final isFailed = draft.status == ChatAttachmentDraftStatus.failed;
          return Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: isFailed
                  ? colors.errorContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (draft.status == ChatAttachmentDraftStatus.preparing)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isFailed
                        ? Icons.error_outline_rounded
                        : isDocument
                        ? Icons.description_outlined
                        : isAudio
                        ? Icons.audio_file_outlined
                        : Icons.image_outlined,
                    size: 18,
                    color: isFailed ? colors.error : colors.primary,
                  ),
                const SizedBox(width: 7),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (isFailed)
                        Text(
                          draft.errorMessage ?? 'Preparation failed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: colors.error),
                        ),
                    ],
                  ),
                ),
                if (isDocument &&
                    attachment != null &&
                    onAddToWorkspace != null)
                  IconButton(
                    key: ValueKey('index-attachment-${draft.id}'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add to workspace knowledge',
                    onPressed: () => onAddToWorkspace!(attachment),
                    icon: const Icon(Icons.library_add_outlined, size: 18),
                  ),
                IconButton(
                  key: ValueKey('remove-attachment-${draft.id}'),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove attachment',
                  onPressed: () => onRemove(draft.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
