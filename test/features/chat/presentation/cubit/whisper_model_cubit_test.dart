import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/data/services/whisper_model_provisioner.dart';
import 'package:gena/features/chat/presentation/cubit/whisper_model_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

class _FakeModelManager implements WhisperModelManager {
  bool installed = false;
  bool cancelled = false;
  final ensuredProfiles = <WhisperModelProfile>[];

  @override
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  }) async {
    ensuredProfiles.add(profile);
    onProgress?.call(0.35, 'Downloading ${profile.label} 35%');
    installed = true;
    onProgress?.call(1, '${profile.label} is ready');
    return '/models/${profile.fileName}';
  }

  @override
  Future<bool> isInstalled(WhisperModelProfile profile) async => installed;

  @override
  Future<bool> cancel(WhisperModelProfile profile) async {
    cancelled = true;
    return true;
  }
}

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

  test('selection immediately prepares the chosen model', () async {
    final manager = _FakeModelManager();
    final cubit = WhisperModelCubit(modelManager: manager);
    addTearDown(cubit.close);
    final emitted = <WhisperModelState>[];
    final subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    await cubit.selectProfile(WhisperModelProfile.base);
    await Future<void>.delayed(Duration.zero);

    expect(manager.ensuredProfiles, <WhisperModelProfile>[
      WhisperModelProfile.base,
    ]);
    expect(
      emitted.map((state) => state.status),
      containsAllInOrder(<WhisperModelStatus>[
        WhisperModelStatus.checking,
        WhisperModelStatus.queued,
        WhisperModelStatus.downloading,
        WhisperModelStatus.ready,
      ]),
    );
    expect(cubit.state.profile, WhisperModelProfile.base);
    expect(cubit.state.status, WhisperModelStatus.ready);
  });

  test('unknown persisted profile safely falls back to tiny', () {
    final cubit = WhisperModelCubit();
    addTearDown(cubit.close);

    final restored = cubit.fromJson(<String, dynamic>{
      'profile': 'future-large-model',
    });

    expect(restored?.profile, WhisperModelProfile.tiny);
  });

  test('reports foreground download progress and ready state', () async {
    final manager = _FakeModelManager();
    final cubit = WhisperModelCubit(modelManager: manager);
    addTearDown(cubit.close);
    final emitted = <WhisperModelState>[];
    final subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    await cubit.ensureReady(WhisperModelProfile.tiny);
    await Future<void>.delayed(Duration.zero);

    expect(
      emitted.any(
        (state) =>
            state.status == WhisperModelStatus.downloading &&
            state.progress == 0.35,
      ),
      isTrue,
    );
    expect(cubit.state.status, WhisperModelStatus.ready);
    expect(cubit.state.progress, 1);
  });

  test('cancels the selected model download', () async {
    final manager = _FakeModelManager();
    final cubit = WhisperModelCubit(modelManager: manager);
    addTearDown(cubit.close);

    await cubit.cancelDownload();

    expect(manager.cancelled, isTrue);
    expect(cubit.state.status, WhisperModelStatus.cancelled);
  });
}
