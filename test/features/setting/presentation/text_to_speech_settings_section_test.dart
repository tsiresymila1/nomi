import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/local_neural_text_to_speech.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/chat/presentation/cubit/llamadart_tts_model_cubit.dart';
import 'package:gena/features/setting/presentation/cubit/text_to_speech_settings_cubit.dart';
import 'package:gena/features/setting/presentation/widgets/text_to_speech_settings_section.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../support/in_memory_hydrated_storage.dart';

class _FlutterTtsFake extends FlutterTts {
  final spoken = <String>[];

  @override
  Future<dynamic> get getEngines async => <String>['com.google.android.tts'];

  @override
  Future<dynamic> get getVoices async => <Map<String, String>>[
    <String, String>{
      'name': 'fr-local',
      'locale': 'fr-FR',
      'quality': 'high',
      'latency': 'low',
      'network_required': '0',
    },
  ];

  @override
  Future<dynamic> setEngine(String engine) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    startHandler?.call();
    return 1;
  }
}

const _capabilities = AppCapabilities(
  platform: AppPlatform.android,
  supportsRemoteModels: true,
  supportsLocalModels: true,
  supportsWorkspaceRag: true,
  supportsSpeechToText: true,
  supportsTextToSpeech: true,
  supportsMcp: true,
);

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  testWidgets('shows installed offline voice and previews it', (tester) async {
    final platformTts = _FlutterTtsFake();
    final tts = FlutterTextToSpeech(
      tts: platformTts,
      capabilities: _capabilities,
    );
    final cubit = TextToSpeechSettingsCubit();
    addTearDown(tts.dispose);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TextToSpeechSettingsSection(cubit: cubit, textToSpeech: tts),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voice output (TTS)'));
    await tester.pumpAndSettle();
    expect(find.text('Voice model'), findsOneWidget);

    await tester.tap(find.text('Voice model'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended'), findsOneWidget);
    await tester.tap(find.text('fr-FR'));
    await tester.pumpAndSettle();

    expect(cubit.state.voiceName, 'fr-local');
    expect(cubit.state.voiceLocale, 'fr-FR');

    await tester.tap(find.text('Preview voice'));
    await tester.pump();
    expect(platformTts.spoken, hasLength(1));
  });

  testWidgets('confirms, installs and preloads the LlamaDart voice', (
    tester,
  ) async {
    final platformTts = _FlutterTtsFake();
    final nativeTts = FlutterTextToSpeech(
      tts: platformTts,
      capabilities: _capabilities,
    );
    final settings = TextToSpeechSettingsCubit();
    final store = _TtsModelStoreFake();
    final localTts = _LocalTtsFake();
    final modelCubit = LlamaDartTtsModelCubit(
      store: store,
      textToSpeech: localTts,
    );
    addTearDown(nativeTts.dispose);
    addTearDown(settings.close);
    addTearDown(modelCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TextToSpeechSettingsSection(
              cubit: settings,
              textToSpeech: nativeTts,
              llamaDartCubit: modelCubit,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice output (TTS)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local AI'));
    await tester.pumpAndSettle();
    expect(find.text('Use Local AI voice?'), findsOneWidget);
    await tester.tap(find.text('Use Local AI'));
    await tester.pumpAndSettle();

    expect(settings.state.backend, TextToSpeechBackend.llamaDart);
    expect(find.text('Install model'), findsOneWidget);
    await tester.tap(find.text('Install model'));
    await tester.pumpAndSettle();

    expect(localTts.prepareCount, 1);
    expect(find.text('Ready'), findsOneWidget);
  });
}

class _TtsModelStoreFake implements LlamaDartTtsModelStore {
  bool installed = false;

  @override
  bool get isSupported => true;

  InstalledLlamaDartTtsModel get _installed => InstalledLlamaDartTtsModel(
    profile: qwen3Tts17bQ4,
    modelPath: '/model.gguf',
    projectorPath: '/mmproj.gguf',
  );

  @override
  Future<void> cancelInstall(LlamaDartTtsModelProfile profile) async {}

  @override
  Future<void> delete(LlamaDartTtsModelProfile profile) async {
    installed = false;
  }

  @override
  Future<InstalledLlamaDartTtsModel> install(
    LlamaDartTtsModelProfile profile, {
    required void Function(double progress, String message) onProgress,
    required void Function(String message) onVerifying,
  }) async {
    installed = true;
    onProgress(1, 'Downloaded');
    onVerifying('Verified');
    return _installed;
  }

  @override
  Future<InstalledLlamaDartTtsModel?> resolve(
    LlamaDartTtsModelProfile profile,
  ) async => installed ? _installed : null;
}

class _LocalTtsFake implements LocalNeuralTextToSpeech {
  int prepareCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<bool> get speakingChanges => const Stream<bool>.empty();

  @override
  Future<void> clear() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> enqueue(String text) async {}

  @override
  Future<void> prepare() async {
    prepareCount++;
  }

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> unload() async {}
}
