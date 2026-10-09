import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/presentation/cubit/chat_composer_mode_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/widgets/chat_composer_mode_selector.dart';
import 'package:gena/features/image_generation/presentation/widgets/image_generation_status_panel.dart';

void main() {
  testWidgets('mode selector switches to explicit image mode', (tester) async {
    ChatComposerMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerModeSelector(
            mode: ChatComposerMode.text,
            onSelected: (mode) => selected = mode,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Image'));

    expect(selected, ChatComposerMode.image);
  });

  testWidgets('install panel explains local model size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationStatusPanel(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.needsInstall,
            ),
            onInstall: () {},
            onCancelInstall: () {},
            onCancelGeneration: () {},
            onRetry: () {},
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(find.text('Install SDXS-512'), findsOneWidget);
    expect(find.textContaining('683 MB'), findsOneWidget);
    expect(find.textContaining('stays on this device'), findsOneWidget);
  });

  testWidgets('generation panel exposes phase progress and stop', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationStatusPanel(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.generating,
              isInstalled: true,
              progress: LocalImageGenerationProgress(
                phase: LocalImageGenerationPhase.sampling,
                step: 1,
                steps: 4,
              ),
            ),
            onInstall: () {},
            onCancelInstall: () {},
            onCancelGeneration: () => stopped = true,
            onRetry: () {},
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(find.text('Drawing image · 1/4'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(stopped, isTrue);
  });

  testWidgets('status panel labels the selected image model', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageGenerationStatusPanel(
            state: const ImageGenerationState(
              phase: ImageGenerationUiPhase.needsInstall,
              profile: ImageModelCatalog.stableDiffusion15Q4,
            ),
            onInstall: () {},
            onCancelInstall: () {},
            onCancelGeneration: () {},
            onRetry: () {},
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(find.text('Install Stable Diffusion 1.5 Q4'), findsOneWidget);
    expect(find.textContaining('1.5 GB'), findsOneWidget);
    expect(find.textContaining('SDXS-512'), findsNothing);
  });
}
