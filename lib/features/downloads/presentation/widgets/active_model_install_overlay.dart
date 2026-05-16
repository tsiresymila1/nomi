import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/presentation/providers/download_notifier.dart';

class ActiveModelInstallOverlay extends ConsumerWidget {
  const ActiveModelInstallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeInstall = ref.watch(activeModelInstallProvider);
    final downloads = ref.watch(downloadProvider);

    if (activeInstall == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Installing ${activeInstall.label}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (downloads[activeInstall.key] == null)
                  const Center(child: CircularProgressIndicator())
                else
                  LinearProgressIndicator(value: downloads[activeInstall.key]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
