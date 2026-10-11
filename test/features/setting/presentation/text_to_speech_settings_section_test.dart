import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gena/core/platform/app_capabilities.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
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
}
