import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/whisper_model_cubit.dart';
import 'package:gena/features/chat/presentation/cubit/llamadart_tts_model_cubit.dart';
import 'package:gena/features/downloads/data/services/download_notifier_service.dart';
import 'package:gena/features/downloads/presentation/widgets/download_models_list.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';
import 'package:gena/features/setting/presentation/cubit/text_to_speech_settings_cubit.dart';
import 'package:gena/features/setting/presentation/widgets/image_model_settings_section.dart';
import 'package:gena/features/setting/presentation/widgets/text_to_speech_settings_section.dart';
import 'package:gena/features/setting/presentation/widgets/whisper_model_settings_section.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

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
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Text & multimodal'),
              Tab(text: 'STT'),
              Tab(text: 'TTS'),
              Tab(text: 'Image'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            const DownloadModelsList(),
            _ModelSettingsTab(
              child: WhisperModelSettingsSection(
                cubit: sl<WhisperModelCubit>(),
              ),
            ),
            _ModelSettingsTab(
              child: TextToSpeechSettingsSection(
                cubit: sl<TextToSpeechSettingsCubit>(),
                textToSpeech: sl<FlutterTextToSpeech>(),
                llamaDartCubit: sl<LlamaDartTtsModelCubit>(),
                playback: sl<TextToSpeech>(),
                initiallyExpanded: true,
              ),
            ),
            _ModelSettingsTab(
              child: ImageModelSettingsSection(
                selectionCubit: sl<ImageModelSelectionCubit>(),
                generationCubit: sl<ImageGenerationCubit>(),
              ),
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                mini: true,
                tooltip: 'Add text model',
                onPressed: () => context.pushNamed('add-model'),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
              )
            : null,
      ),
    );
  }
}

class _ModelSettingsTab extends StatelessWidget {
  const _ModelSettingsTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [child],
    );
  }
}
