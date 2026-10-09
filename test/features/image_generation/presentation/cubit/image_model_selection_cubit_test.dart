import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../../support/in_memory_hydrated_storage.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryHydratedStorage();
  });

  test('defaults to SDXS for 4 GB Android devices', () {
    final cubit = ImageModelSelectionCubit();
    addTearDown(cubit.close);

    expect(cubit.state.selectedProfile, ImageModelCatalog.sdxs);
    expect(cubit.state.allProfiles, ImageModelCatalog.builtIn);
  });

  test('persists and restores a built-in selection', () async {
    final first = ImageModelSelectionCubit();
    first.select(ImageModelCatalog.stableDiffusion15Q4.id);
    await first.close();

    final second = ImageModelSelectionCubit();
    addTearDown(second.close);

    expect(second.state.selectedProfile, ImageModelCatalog.stableDiffusion15Q4);
  });

  test('unknown persisted selection safely falls back to SDXS', () {
    final cubit = ImageModelSelectionCubit();
    addTearDown(cubit.close);

    final restored = cubit.fromJson(<String, dynamic>{
      'selectedId': 'future-image-model',
      'customProfiles': <Object?>[],
    });

    expect(restored?.selectedId, ImageModelCatalog.sdxs.id);
    expect(restored?.selectedProfile, ImageModelCatalog.sdxs);
  });

  test('registers a custom profile and restores its metadata', () async {
    final first = ImageModelSelectionCubit();
    final profile = first.registerExternal(
      name: 'Portrait model',
      filePath: '/storage/emulated/0/Models/portrait.gguf',
      sizeBytes: 1234,
    );
    first.select(profile.id);
    await first.close();

    final second = ImageModelSelectionCubit();
    addTearDown(second.close);

    expect(second.state.customProfiles, hasLength(1));
    expect(second.state.selectedProfile.id, profile.id);
    expect(second.state.selectedProfile.filePath, profile.filePath);
  });

  test('registering the same normalized path replaces its metadata', () {
    final cubit = ImageModelSelectionCubit();
    addTearDown(cubit.close);

    final first = cubit.registerExternal(
      name: 'Old name',
      filePath: '/storage/emulated/0/Models/portrait.gguf',
      sizeBytes: 100,
    );
    final replacement = cubit.registerExternal(
      name: 'New name',
      filePath: '/storage/emulated/0/Models/./portrait.gguf',
      sizeBytes: 200,
    );

    expect(replacement.id, first.id);
    expect(cubit.state.customProfiles, hasLength(1));
    expect(cubit.state.customProfiles.single.name, 'New name');
    expect(cubit.state.customProfiles.single.sizeBytes, 200);
  });

  test('removing the selected custom profile falls back to SDXS', () {
    final cubit = ImageModelSelectionCubit();
    addTearDown(cubit.close);
    final profile = cubit.registerExternal(
      name: 'Temporary',
      filePath: '/storage/emulated/0/Models/temporary.gguf',
      sizeBytes: 10,
    );
    cubit.select(profile.id);

    cubit.removeCustom(profile.id);

    expect(cubit.state.customProfiles, isEmpty);
    expect(cubit.state.selectedProfile, ImageModelCatalog.sdxs);
  });

  test('rejects selection of an unknown profile', () {
    final cubit = ImageModelSelectionCubit();
    addTearDown(cubit.close);

    expect(() => cubit.select('missing'), throwsA(isA<ArgumentError>()));
  });
}
