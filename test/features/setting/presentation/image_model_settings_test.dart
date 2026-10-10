import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_actions.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';
import 'package:gena/features/setting/presentation/widgets/image_model_settings_section.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../support/in_memory_hydrated_storage.dart';

void main() {
  late ImageModelSelectionCubit selection;
  late ImageGenerationCubit generation;
  late _FakeImageActions actions;

  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
    selection = ImageModelSelectionCubit();
    actions = _FakeImageActions();
    generation = ImageGenerationCubit(actions, selection: selection);
  });

  tearDown(() async {
    await generation.close();
    await selection.close();
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    Future<String?> Function()? pathPicker,
    Future<int> Function(String path)? fileSizeResolver,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ImageModelSettingsSection(
              selectionCubit: selection,
              generationCubit: generation,
              pathPicker: pathPicker,
              fileSizeResolver: fileSizeResolver,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows all built-ins and the 4 GB recommendation', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Image generation'), findsOneWidget);
    expect(find.text('SDXS-512'), findsOneWidget);
    expect(find.text('Stable Diffusion 1.5 Q4'), findsOneWidget);
    expect(find.text('DreamShaper 8 LCM Q4'), findsOneWidget);
    expect(find.text('SDXL Turbo Q4'), findsOneWidget);
    expect(find.text('Recommended for 4 GB'), findsOneWidget);
    expect(find.text('Compatible from 6 GB'), findsOneWidget);
    expect(find.textContaining('Experimental'), findsNWidgets(2));
  });

  testWidgets('shows loading then ready while preloading the selected model', (
    tester,
  ) async {
    actions.prepareGate = Completer<void>();
    await pumpSection(tester);
    await tester.pump();

    expect(actions.prepareCalls, 1);
    expect(find.textContaining('Loading…'), findsOneWidget);
    expect(find.text('Loading model…'), findsOneWidget);

    actions.prepareGate!.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready'), findsOneWidget);
  });

  testWidgets('requires confirmation before selecting a heavier model', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Stable Diffusion 1.5 Q4'));
    await tester.pumpAndSettle();

    expect(find.text('Use Stable Diffusion 1.5 Q4?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('4 GB'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selection.state.selectedProfile, ImageModelCatalog.sdxs);

    await tester.tap(find.text('Stable Diffusion 1.5 Q4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use model'));
    await tester.pumpAndSettle();

    expect(
      selection.state.selectedProfile,
      ImageModelCatalog.stableDiffusion15Q4,
    );
    expect(actions.releaseCalls, 1);
    expect(actions.prepareCalls, 2);
  });

  testWidgets('registers the original custom GGUF path without copying', (
    tester,
  ) async {
    var pickerCalls = 0;
    const path = '/storage/emulated/0/Models/custom-image.gguf';
    await pumpSection(
      tester,
      pathPicker: () async {
        pickerCalls++;
        return path;
      },
      fileSizeResolver: (selectedPath) async {
        expect(selectedPath, path);
        return 900000000;
      },
    );

    await tester.tap(find.text('Add GGUF model'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(find.text('custom-image'), findsOneWidget);
    expect(selection.state.customProfiles, hasLength(1));
    expect(selection.state.selectedProfile.filePath, path);
    expect(selection.state.selectedProfile.isExternal, isTrue);
    expect(actions.releaseCalls, 1);
  });

  testWidgets(
    'relocates a missing custom model without retaining the old path',
    (tester) async {
      final oldProfile = selection.registerExternal(
        name: 'custom-image',
        filePath: '/storage/emulated/0/Old/custom-image.gguf',
        sizeBytes: 100,
      );
      selection.select(oldProfile.id);
      const newPath = '/storage/emulated/0/Models/custom-image.gguf';
      await pumpSection(
        tester,
        pathPicker: () async => newPath,
        fileSizeResolver: (_) async => 200,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Locate again'));
      await tester.tap(find.text('Locate again'));
      await tester.pumpAndSettle();

      expect(selection.state.customProfiles, hasLength(1));
      expect(selection.state.selectedProfile.filePath, newPath);
      expect(selection.state.selectedProfile.sizeBytes, 200);
    },
  );
}

class _FakeImageActions implements ImageGenerationActionsApi {
  int releaseCalls = 0;
  int prepareCalls = 0;
  Completer<void>? prepareGate;
  InstalledImageModel? installed = const InstalledImageModel(
    profile: ImageModelProfile.sdxs,
    modelPath: '/models/sdxs.gguf',
  );

  @override
  Future<InstalledImageModel> prepareModel() async {
    prepareCalls++;
    await prepareGate?.future;
    return installed ?? (throw StateError('Model is not installed'));
  }

  @override
  Future<void> cancelInstall() async {}

  @override
  void cancelGeneration() {}

  @override
  Future<ImageRuntimeSupport> checkSupport() async =>
      const ImageRuntimeSupport(isSupported: true);

  @override
  Future<GeneratedImageArtifact> generateAndPersist({
    required String prompt,
    int? seed,
    bool persistPrompt = true,
    required void Function(LocalImageGenerationProgress progress) onProgress,
  }) => throw UnimplementedError();

  @override
  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) => throw UnimplementedError();

  @override
  Future<void> releaseEngine() async {
    releaseCalls++;
  }

  @override
  Future<void> removeModel() async {}

  @override
  Future<InstalledImageModel?> resolveModel() async => installed;
}
