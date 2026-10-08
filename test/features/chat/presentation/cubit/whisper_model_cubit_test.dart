import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/presentation/cubit/whisper_model_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  test('defaults to multilingual tiny for 4 GB devices', () {
    final cubit = WhisperModelCubit();
    addTearDown(cubit.close);

    expect(cubit.state.profile, WhisperModelProfile.tiny);
    expect(cubit.state.profile.isMultilingual, isTrue);
    expect(cubit.state.profile.fileName, 'ggml-tiny.bin');
  });

  test('persists and restores the selected profile', () async {
    final first = WhisperModelCubit();
    await first.selectProfile(WhisperModelProfile.base);
    await first.close();

    final second = WhisperModelCubit();
    addTearDown(second.close);

    expect(second.state.profile, WhisperModelProfile.base);
  });

  test('unknown persisted profile safely falls back to tiny', () {
    final cubit = WhisperModelCubit();
    addTearDown(cubit.close);

    final restored = cubit.fromJson(<String, dynamic>{
      'profile': 'future-large-model',
    });

    expect(restored?.profile, WhisperModelProfile.tiny);
  });
}
