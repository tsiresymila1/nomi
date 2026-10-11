import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/text_to_speech.dart';
import 'package:gena/features/setting/presentation/cubit/text_to_speech_settings_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  test(
    'persists the selected TTS engine, voice and inference controls',
    () async {
      final first = TextToSpeechSettingsCubit();
      first.selectBackend(TextToSpeechBackend.llamaDart);
      first.selectEngine('com.google.android.tts');
      first.selectVoice(
        const TextToSpeechVoice(name: 'local-fr', locale: 'fr-FR'),
      );
      first.setSpeechRate(0.65);
      first.setPitch(1.1);
      await Future<void>.delayed(Duration.zero);
      await first.close();

      final restored = TextToSpeechSettingsCubit();
      addTearDown(restored.close);

      expect(restored.state.engine, 'com.google.android.tts');
      expect(restored.state.backend, TextToSpeechBackend.llamaDart);
      expect(restored.state.voiceName, 'local-fr');
      expect(restored.state.voiceLocale, 'fr-FR');
      expect(restored.state.speechRate, 0.65);
      expect(restored.state.pitch, 1.1);
    },
  );
}
