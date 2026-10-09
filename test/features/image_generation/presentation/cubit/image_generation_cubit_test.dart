import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_actions.dart';
import 'package:gena/features/image_generation/presentation/cubit/chat_composer_mode_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';

void main() {
  group('ChatComposerModeCubit', () {
    test('switches explicitly between text and image', () async {
      final cubit = ChatComposerModeCubit();
      addTearDown(cubit.close);

      cubit.select(ChatComposerMode.image);
      expect(cubit.state, ChatComposerMode.image);

      cubit.select(ChatComposerMode.text);
      expect(cubit.state, ChatComposerMode.text);
    });
  });

  group('ImageGenerationCubit', () {
    late _FakeImageGenerationActions actions;
    late ImageGenerationCubit cubit;

    setUp(() {
      actions = _FakeImageGenerationActions();
      cubit = ImageGenerationCubit(actions);
    });

    tearDown(() => cubit.close());

    test('initializes to needsInstall when SDXS is absent', () async {
      actions.installed = null;

      await cubit.initialize();

      expect(cubit.state.phase, ImageGenerationUiPhase.needsInstall);
      expect(cubit.state.support?.isSupported, isTrue);
    });

    test('initializes to ready when SDXS is installed', () async {
      await cubit.initialize();

      expect(cubit.state.phase, ImageGenerationUiPhase.ready);
      expect(cubit.state.isInstalled, isTrue);
    });

    test(
      'surfaces an unsupported runtime without resolving the model',
      () async {
        actions.support = const ImageRuntimeSupport(
          isSupported: false,
          unsupportedReason: 'No native runtime',
        );

        await cubit.initialize();

        expect(cubit.state.phase, ImageGenerationUiPhase.unsupported);
        expect(cubit.state.errorMessage, 'No native runtime');
        expect(actions.resolveCalls, 0);
      },
    );

    test('reports download and verification progress', () async {
      actions.installed = null;
      await cubit.initialize();
      final states = <ImageGenerationState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      await cubit.installModel();
      await Future<void>.delayed(Duration.zero);

      expect(
        states.map((state) => state.phase),
        containsAllInOrder(<ImageGenerationUiPhase>[
          ImageGenerationUiPhase.downloading,
          ImageGenerationUiPhase.verifying,
          ImageGenerationUiPhase.ready,
        ]),
      );
      expect(cubit.state.downloadProgress, 1);
      expect(cubit.state.isInstalled, isTrue);
    });

    test('generates, persists, and exposes progress', () async {
      await cubit.initialize();
      final states = <ImageGenerationState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final artifact = await cubit.generate('  a paper boat  ', seed: 11);
      await Future<void>.delayed(Duration.zero);

      expect(actions.prompts, <String>['a paper boat']);
      expect(actions.seeds, <int?>[11]);
      expect(artifact?.path, '/generated/image.png');
      expect(
        states.map((state) => state.phase),
        containsAllInOrder(<ImageGenerationUiPhase>[
          ImageGenerationUiPhase.loadingModel,
          ImageGenerationUiPhase.generating,
          ImageGenerationUiPhase.completed,
        ]),
      );
      expect(cubit.state.progress?.step, 1);
    });

    test('cancels active generation and settles into cancelled', () async {
      actions.blockGeneration = true;
      await cubit.initialize();
      final generation = cubit.generate('cancel me');
      await actions.generationStarted.future;

      cubit.cancelGeneration();
      await generation;

      expect(actions.cancelGenerationCalls, 1);
      expect(cubit.state.phase, ImageGenerationUiPhase.cancelled);
    });

    test('removes SDXS and returns to needsInstall', () async {
      await cubit.initialize();

      await cubit.removeModel();

      expect(actions.removeCalls, 1);
      expect(cubit.state.phase, ImageGenerationUiPhase.needsInstall);
      expect(cubit.state.isInstalled, isFalse);
    });
  });
}

class _FakeImageGenerationActions implements ImageGenerationActionsApi {
  ImageRuntimeSupport support = const ImageRuntimeSupport(isSupported: true);
  InstalledImageModel? installed = const InstalledImageModel(
    profile: ImageModelProfile.sdxs,
    modelPath: '/models/sdxs.gguf',
  );
  int resolveCalls = 0;
  int cancelGenerationCalls = 0;
  int removeCalls = 0;
  bool blockGeneration = false;
  final prompts = <String>[];
  final seeds = <int?>[];
  final generationStarted = Completer<void>();
  Completer<void>? _blocked;

  @override
  Future<void> cancelInstall() async {}

  @override
  void cancelGeneration() {
    cancelGenerationCalls++;
    _blocked?.complete();
  }

  @override
  Future<ImageRuntimeSupport> checkSupport() async => support;

  @override
  Future<GeneratedImageArtifact> generateAndPersist({
    required String prompt,
    int? seed,
    required void Function(LocalImageGenerationProgress progress) onProgress,
  }) async {
    prompts.add(prompt);
    seeds.add(seed);
    if (!generationStarted.isCompleted) generationStarted.complete();
    if (blockGeneration) {
      _blocked = Completer<void>();
      await _blocked!.future;
      throw const ImageGenerationCancelledException();
    }
    onProgress(
      const LocalImageGenerationProgress(
        phase: LocalImageGenerationPhase.sampling,
        step: 1,
        steps: 1,
      ),
    );
    return const GeneratedImageArtifact(
      path: '/generated/image.png',
      seed: 11,
      width: 512,
      height: 512,
      elapsed: Duration(seconds: 1),
      profile: ImageModelProfile.sdxs,
    );
  }

  @override
  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) async {
    onProgress(0.5);
    onVerifying();
    onProgress(1);
    return installed = const InstalledImageModel(
      profile: ImageModelProfile.sdxs,
      modelPath: '/models/sdxs.gguf',
    );
  }

  @override
  Future<void> removeModel() async {
    removeCalls++;
    installed = null;
  }

  @override
  Future<InstalledImageModel?> resolveModel() async {
    resolveCalls++;
    return installed;
  }
}
