import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';

class ActiveModelInstallOverlay extends StatelessWidget {
  const ActiveModelInstallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DownloadsCubit>().state;
    final activeInstall = state.activeInstall;
    final downloads = state.progressByKey;

    if (activeInstall == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
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
