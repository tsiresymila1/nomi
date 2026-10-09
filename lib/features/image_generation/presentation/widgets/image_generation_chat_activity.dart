import 'package:flutter/material.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';

bool shouldShowImageGenerationActivity(
  ImageGenerationState state,
  String chatId,
) {
  final hasActiveTurn =
      state.activePrompt?.trim().isNotEmpty == true &&
      state.activeChatId == chatId;
  if (!hasActiveTurn) return false;
  return switch (state.phase) {
    ImageGenerationUiPhase.loadingModel ||
    ImageGenerationUiPhase.generating ||
    ImageGenerationUiPhase.failed ||
    ImageGenerationUiPhase.cancelled => true,
    _ => false,
  };
}

class ImageGenerationChatActivity extends StatelessWidget {
  const ImageGenerationChatActivity({
    super.key,
    required this.state,
    required this.onCancel,
    required this.onRetry,
  });

  final ImageGenerationState state;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final presentation = switch (state.phase) {
      ImageGenerationUiPhase.loadingModel => (
        icon: Icons.memory_rounded,
        title: 'Loading ${state.profile.name}',
        subtitle: 'Preparing the local image model…',
        progress: null,
        indeterminate: true,
        isError: false,
        actionLabel: 'Cancel',
        action: onCancel,
      ),
      ImageGenerationUiPhase.generating => (
        icon: Icons.brush_rounded,
        title: _progressLabel(state.progress),
        subtitle: 'Generating privately on this device.',
        progress: state.progress?.fraction,
        indeterminate: state.progress == null,
        isError: false,
        actionLabel: 'Stop',
        action: onCancel,
      ),
      ImageGenerationUiPhase.failed => (
        icon: Icons.error_outline_rounded,
        title: 'Image generation failed',
        subtitle: state.errorMessage ?? 'Please try again.',
        progress: null,
        indeterminate: false,
        isError: true,
        actionLabel: 'Retry',
        action: onRetry,
      ),
      ImageGenerationUiPhase.cancelled => (
        icon: Icons.stop_circle_outlined,
        title: 'Image generation cancelled',
        subtitle: 'Your prompt is still available in this chat.',
        progress: null,
        indeterminate: false,
        isError: false,
        actionLabel: 'Retry',
        action: onRetry,
      ),
      _ => null,
    };
    if (presentation == null) return const SizedBox.shrink();

    final accent = presentation.isError ? colors.error : colors.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('image-generation-activity'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        decoration: BoxDecoration(
          color: presentation.isError
              ? colors.errorContainer
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(
            color: presentation.isError
                ? colors.error.withValues(alpha: 0.35)
                : colors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(presentation.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    presentation.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (presentation.progress != null ||
                      presentation.indeterminate) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: presentation.progress),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: ValueKey(
                presentation.actionLabel == 'Retry'
                    ? 'retry-image-generation'
                    : 'cancel-image-generation',
              ),
              onPressed: presentation.action,
              child: Text(presentation.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _progressLabel(LocalImageGenerationProgress? progress) {
  if (progress == null) return 'Generating image';
  final phase = switch (progress.phase) {
    LocalImageGenerationPhase.loading => 'Loading weights',
    LocalImageGenerationPhase.encodingPrompt => 'Understanding prompt',
    LocalImageGenerationPhase.sampling => 'Drawing image',
    LocalImageGenerationPhase.decoding => 'Finishing image',
  };
  if (progress.steps <= 0) return phase;
  return '$phase · ${progress.step}/${progress.steps}';
}
