import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/downloads/presentation/widgets/active_model_install_overlay.dart';
import 'package:gena/features/downloads/presentation/widgets/add_model_sheet.dart';
import 'package:gena/features/downloads/presentation/widgets/download_models_list.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Models',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: const Stack(
        children: [DownloadModelsList(), ActiveModelInstallOverlay()],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () => showAddModelSheet(context, ref),
        child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
      ),
    );
  }
}
