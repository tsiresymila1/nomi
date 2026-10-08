import 'package:flutter/material.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';

class ImageGenerationStatusPanel extends StatelessWidget {
  const ImageGenerationStatusPanel({
    super.key,
    required this.state,
    required this.onInstall,
    required this.onCancelInstall,
    required this.onCancelGeneration,
    required this.onRetry,
    required this.onRemove,
  });

  final ImageGenerationState state;
  final VoidCallback onInstall;
  final VoidCallback onCancelInstall;
  final VoidCallback onCancelGeneration;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (state.phase) {
        ImageGenerationUiPhase.initial ||
        ImageGenerationUiPhase.checking => _StatusCard(
          key: const ValueKey('image-checking'),
          icon: Icons.auto_awesome_rounded,
          title: 'Preparing image generation',
          subtitle: 'Checking the private local runtime…',
          indeterminate: true,
        ),
        ImageGenerationUiPhase.needsInstall => _StatusCard(
          key: const ValueKey('image-needs-install'),
          icon: Icons.download_rounded,
          title: 'Install SDXS-512',
          subtitle: 'Fast local GGUF model · 683 MB · stays on this device',
          action: FilledButton.tonalIcon(
            onPressed: onInstall,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ),
        ImageGenerationUiPhase.downloading => _StatusCard(
          key: const ValueKey('image-downloading'),
          icon: Icons.downloading_rounded,
          title:
              'Downloading SDXS-512 · ${(state.downloadProgress * 100).round()}%',
          subtitle: 'The download can continue in the background.',
          progress: state.downloadProgress,
          action: TextButton(
            onPressed: onCancelInstall,
            child: const Text('Cancel'),
          ),
        ),
        ImageGenerationUiPhase.verifying => const _StatusCard(
          key: ValueKey('image-verifying'),
          icon: Icons.verified_user_outlined,
          title: 'Verifying model integrity',
          subtitle: 'Checking SHA-256 before loading the model…',
          indeterminate: true,
        ),
        ImageGenerationUiPhase.loadingModel => _StatusCard(
          key: const ValueKey('image-loading-model'),
          icon: Icons.memory_rounded,
          title: 'Loading SDXS-512',
          subtitle: 'Releasing other local AI models to protect memory.',
          indeterminate: true,
          action: TextButton(
            onPressed: onCancelGeneration,
            child: const Text('Cancel'),
          ),
        ),
        ImageGenerationUiPhase.generating => _StatusCard(
          key: const ValueKey('image-generating'),
          icon: Icons.brush_rounded,
          title: _generationLabel(state.progress),
          subtitle: 'Generating privately on this device.',
          progress: state.progress?.fraction,
          indeterminate: state.progress == null,
          action: TextButton(
            onPressed: onCancelGeneration,
            child: const Text('Stop'),
          ),
        ),
        ImageGenerationUiPhase.unsupported => _StatusCard(
          key: const ValueKey('image-unsupported'),
          icon: Icons.info_outline_rounded,
          title: 'Image generation unavailable',
          subtitle: state.errorMessage ?? 'This device is not supported.',
        ),
        ImageGenerationUiPhase.failed => _StatusCard(
          key: const ValueKey('image-failed'),
          icon: Icons.error_outline_rounded,
          iconColor: colors.error,
          title: 'Image generation failed',
          subtitle: state.errorMessage ?? 'Please try again.',
          action: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ),
        ImageGenerationUiPhase.removing => const _StatusCard(
          key: ValueKey('image-removing'),
          icon: Icons.delete_outline_rounded,
          title: 'Removing SDXS-512',
          subtitle: 'Freeing local storage…',
          indeterminate: true,
        ),
        ImageGenerationUiPhase.ready ||
        ImageGenerationUiPhase.completed ||
        ImageGenerationUiPhase.cancelled => _ReadyRow(
          key: const ValueKey('image-ready'),
          onRemove: onRemove,
          status: state.phase == ImageGenerationUiPhase.cancelled
              ? 'Generation cancelled · SDXS-512 ready'
              : 'SDXS-512 ready · 512 × 512 · local',
        ),
      },
    );
  }
}

String _generationLabel(LocalImageGenerationProgress? progress) {
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

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({super.key, required this.status, required this.onRemove});

  final String status;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.offline_bolt_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(status, style: Theme.of(context).textTheme.labelSmall),
          ),
          IconButton(
            key: const ValueKey('remove-image-model'),
            tooltip: 'Remove image model',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.progress,
    this.indeterminate = false,
    this.action,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final double? progress;
  final bool indeterminate;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ] else if (indeterminate) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}
