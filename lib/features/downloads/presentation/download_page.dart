import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';
import 'package:gena/features/downloads/presentation/widgets/download_models_list.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<DownloadsCubit>(),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Models',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Remote servers',
              onPressed: () => context.pushNamed('remote-servers'),
              icon: const Icon(Icons.cloud_outlined),
            ),
          ],
        ),
        body: const DownloadModelsList(),
        floatingActionButton: FloatingActionButton(
          mini: true,
          onPressed: () => context.pushNamed('add-model'),
          child: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
        ),
      ),
    );
  }
}
