# Selectable Image Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one persisted image-model selection in Settings that drives every chat image generation, supports two pinned GGUF catalog models, and registers custom Android GGUF files without copying them.

**Architecture:** A hydrated `ImageModelSelectionCubit` owns the selected profile and custom profile metadata. `LocalImageGenerationService` snapshots that selection for every serialized lifecycle operation and reloads its engine when the selected profile changes. Settings exposes selection/import management while `ImageGenerationCubit` and the chat status panel display the same active profile.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, flutter_bloc/hydrated_bloc, GetIt, llamadart 0.11.0, stable-diffusion.cpp Flutter runtime, existing direct Android model picker, flutter_test

---

## File Structure

- Create `lib/features/image_generation/data/models/image_model_catalog.dart`: pinned built-in image profiles and ID lookup.
- Create `lib/features/image_generation/presentation/cubit/image_model_selection_cubit.dart`: persisted selection and custom model registry.
- Create `lib/features/setting/presentation/widgets/image_model_settings_section.dart`: Settings card, confirmation dialogs, custom import, and model lifecycle actions.
- Create `test/features/image_generation/data/models/image_model_catalog_test.dart`: catalog metadata regression tests.
- Create `test/features/image_generation/presentation/cubit/image_model_selection_cubit_test.dart`: persistence, fallback, and custom registry tests.
- Create `test/features/setting/presentation/image_model_settings_test.dart`: Settings selection/import interaction tests.
- Modify `lib/features/image_generation/data/models/image_generation_models.dart`: profile source/support metadata plus JSON serialization.
- Modify `lib/features/image_generation/data/services/image_model_store_io.dart`: resolve external files without copying and never delete them.
- Modify `lib/features/image_generation/data/services/local_image_generation_service.dart`: dynamically resolve the selected profile and reload on change.
- Modify `lib/features/image_generation/data/services/image_generation_actions.dart`: persist the actual generated model name.
- Modify `lib/features/image_generation/data/image_generation_service_locator.dart`: register and inject the selection cubit.
- Modify `lib/features/image_generation/presentation/cubit/image_generation_cubit.dart`: expose the current profile and refresh after selection changes.
- Modify `lib/features/image_generation/presentation/widgets/image_generation_status_panel.dart`: remove every hard-coded SDXS label.
- Modify `lib/features/setting/presentation/setting_page.dart`: mount the image model settings card.
- Modify existing image-generation tests for profile-aware interfaces and lifecycle behavior.

### Task 1: Catalog, persistence, and custom registry

**Files:**
- Create: `lib/features/image_generation/data/models/image_model_catalog.dart`
- Create: `lib/features/image_generation/presentation/cubit/image_model_selection_cubit.dart`
- Modify: `lib/features/image_generation/data/models/image_generation_models.dart`
- Modify: `lib/features/image_generation/data/image_generation_service_locator.dart`
- Test: `test/features/image_generation/data/models/image_model_catalog_test.dart`
- Test: `test/features/image_generation/presentation/cubit/image_model_selection_cubit_test.dart`

- [ ] **Step 1: Write catalog and selection tests that fail**

Cover immutable SDXS metadata, the pinned SD 1.5 Q4 artifact, profile JSON round trips, hydrated restoration, unknown-ID fallback, custom registration, duplicate-path replacement, and custom removal fallback. Use an external profile shaped as:

```dart
final custom = ImageModelProfile.external(
  id: 'custom:test',
  name: 'My image model',
  filePath: '/storage/emulated/0/Models/image.gguf',
  sizeBytes: 42,
);
```

The SD 1.5 profile must pin:

```dart
id: 'stable-diffusion-v1-5-q4_0'
fileName: 'stable-diffusion-v1-5-pruned-emaonly-Q4_0.gguf'
sizeBytes: 1566768416
sha256: 'b2564c85cbda2ff00b820468ca6ce24ff9c728157d32ff00de874577175d5bba'
steps: 20
guidanceScale: 7.0
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
rtk flutter test test/features/image_generation/data/models/image_model_catalog_test.dart test/features/image_generation/presentation/cubit/image_model_selection_cubit_test.dart
```

Expected: FAIL because the catalog and selection cubit do not exist.

- [ ] **Step 3: Implement serializable profiles and the built-in catalog**

Add source and support enums and constructors with these public shapes:

```dart
enum ImageModelSourceType { managedDownload, externalFile }
enum ImageModelDeviceTier { recommended4Gb, experimental, custom }

class ImageModelProfile {
  const ImageModelProfile({...});
  factory ImageModelProfile.external({...});
  factory ImageModelProfile.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  bool get isExternal => sourceType == ImageModelSourceType.externalFile;
  String get displaySize;
}

abstract final class ImageModelCatalog {
  static const sdxs = ImageModelProfile(...);
  static const stableDiffusion15Q4 = ImageModelProfile(...);
  static const builtIn = <ImageModelProfile>[sdxs, stableDiffusion15Q4];
  static ImageModelProfile? findBuiltIn(String id);
}
```

Keep `ImageModelProfile.sdxs` as a deprecated-compatible alias to avoid an unrelated migration burst.

- [ ] **Step 4: Implement hydrated selection and custom registry**

Use one immutable state:

```dart
class ImageModelSelectionState {
  const ImageModelSelectionState({
    this.selectedId = ImageModelCatalog.sdxsId,
    this.customProfiles = const <ImageModelProfile>[],
  });

  ImageModelProfile get selectedProfile =>
      allProfiles.firstWhere((profile) => profile.id == selectedId,
        orElse: () => ImageModelCatalog.sdxs);
  List<ImageModelProfile> get allProfiles =>
      <ImageModelProfile>[...ImageModelCatalog.builtIn, ...customProfiles];
}
```

Expose `select(String id)`, `registerExternal(...)`, and
`removeCustom(String id)`. Normalize paths before comparison, derive a stable
custom ID from SHA-256 of the path string, and serialize only selected ID plus
custom metadata.

- [ ] **Step 5: Register the cubit before runtime consumers**

Register `ImageModelSelectionCubit` as a guarded lazy singleton in
`registerImageGenerationDependencies()` and inject it into the local service
and image generation cubit.

- [ ] **Step 6: Run tests and verify GREEN**

Run the focused command from Step 2 plus:

```bash
rtk flutter analyze lib/features/image_generation
```

Expected: all focused tests pass and analysis reports no issues.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/features/image_generation/data/models lib/features/image_generation/presentation/cubit/image_model_selection_cubit.dart lib/features/image_generation/data/image_generation_service_locator.dart test/features/image_generation/data/models test/features/image_generation/presentation/cubit/image_model_selection_cubit_test.dart
rtk git commit -m "feat(image): add selectable model catalog"
```

### Task 2: Profile-aware storage and runtime lifecycle

**Files:**
- Modify: `lib/features/image_generation/data/services/image_model_store_io.dart`
- Modify: `lib/features/image_generation/data/services/image_model_store_stub.dart`
- Modify: `lib/features/image_generation/data/services/local_image_generation_service.dart`
- Modify: `lib/features/image_generation/data/services/image_generation_actions.dart`
- Test: `test/features/image_generation/data/services/image_model_store_io_test.dart`
- Test: `test/features/image_generation/data/services/local_image_generation_service_test.dart`
- Test: `test/features/image_generation/data/services/image_generation_actions_test.dart`

- [ ] **Step 1: Write failing lifecycle tests**

Add tests proving that external `resolve()` returns the original path without a
download, `install()` rejects external profiles, `delete()` never removes an
external file, model selection B disposes model A before loading B, generation
captures B's steps/guidance, and assistant metadata contains B's display name.

- [ ] **Step 2: Run the focused service tests and verify RED**

```bash
rtk flutter test test/features/image_generation/data/services/image_model_store_io_test.dart test/features/image_generation/data/services/local_image_generation_service_test.dart test/features/image_generation/data/services/image_generation_actions_test.dart
```

Expected: FAIL on external-file handling and dynamic profile behavior.

- [ ] **Step 3: Make the model store source-aware**

For external profiles, resolve `profile.filePath` directly after checking
existence, readability, `.gguf`, non-zero length, and the persisted size. Do not
compute a checksum unless the custom profile contains one. Throw a clear
`StateError` from install and cancel because external files are not downloads.
Deleting an external profile must return without touching the filesystem.

- [ ] **Step 4: Snapshot selection in every serialized service operation**

Replace the fixed `profile` field with `ImageModelSelectionCubit _selection`.
At the start of each serialized operation use:

```dart
final profile = _selection.state.selectedProfile;
```

Track `_loadedProfileId`. `_ensureGenerator()` may reuse the engine only when
the lease is active and `_loadedProfileId == installed.profile.id`; otherwise
release it before loading the selected model. Clear `_loadedProfileId` during
eviction.

- [ ] **Step 5: Return the generated profile with the artifact**

Add `ImageModelProfile profile` to `GeneratedImageArtifact`. Pass the captured
profile into `_persist()` and use `artifact.profile.name` when inserting the
assistant image message.

- [ ] **Step 6: Run focused tests and analysis**

Run the command from Step 2 and:

```bash
rtk flutter analyze lib/features/image_generation
```

Expected: all tests pass; no analyzer issues.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/features/image_generation/data/services lib/features/image_generation/data/models/image_generation_models.dart test/features/image_generation/data/services
rtk git commit -m "feat(image): switch diffusion models safely"
```

### Task 3: Settings model selection and direct GGUF registration

**Files:**
- Create: `lib/features/setting/presentation/widgets/image_model_settings_section.dart`
- Modify: `lib/features/setting/presentation/setting_page.dart`
- Modify: `lib/features/downloads/data/services/direct_model_file_picker.dart`
- Test: `test/features/setting/presentation/image_model_settings_test.dart`

- [ ] **Step 1: Write failing Settings widget tests**

Render the section with in-memory hydrated storage and fakes. Assert that both
built-ins are visible, SDXS is selected by default, switching to SD 1.5 requires
confirmation and shows the 4 GB warning, cancel keeps SDXS, confirm selects SD
1.5, and importing `/storage/emulated/0/Models/custom.gguf` adds/selects a
Custom row without invoking a copy callback.

- [ ] **Step 2: Run the widget tests and verify RED**

```bash
rtk flutter test test/features/setting/presentation/image_model_settings_test.dart
```

Expected: FAIL because the image settings section does not exist.

- [ ] **Step 3: Generalize the existing direct picker label safely**

Allow `DirectModelFilePicker.pickModelPath()` to receive
`allowedExtensions` and `dialogTitle`. Keep the current defaults for chat model
imports. The image card calls it with only `gguf`; Android continues to return a
direct path through the existing `gena/direct_model_files` channel and
`MANAGE_EXTERNAL_STORAGE` flow.

- [ ] **Step 4: Build the Settings card**

Implement `ImageModelSettingsSection` with injected selection cubit,
`ImageGenerationCubit`, and path-picker callback. Each row derives its label,
size, badge, selection, and availability from state. Selection calls a single
confirmation dialog before `selection.select(profile.id)` and then
`imageGeneration.refreshForSelectedModel()`.

For custom import, validate the path using `File`, build the display name from
the filename without `.gguf`, register it, select it, and refresh image state.
Expose Locate again and Remove from list only for custom entries. Removing a
selected custom entry falls back to SDXS and refreshes runtime state.

- [ ] **Step 5: Mount the card in Settings**

Add the card after `WhisperModelSettingsSection` and use singleton cubits from
GetIt. Preserve the existing animations and spacing.

- [ ] **Step 6: Run widget tests and Settings analysis**

```bash
rtk flutter test test/features/setting/presentation/image_model_settings_test.dart
rtk flutter analyze lib/features/setting lib/features/downloads/data/services/direct_model_file_picker.dart
```

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/features/setting lib/features/downloads/data/services/direct_model_file_picker.dart test/features/setting/presentation/image_model_settings_test.dart
rtk git commit -m "feat(settings): manage image generation models"
```

### Task 4: Chat synchronization, dynamic UX, and release verification

**Files:**
- Modify: `lib/features/image_generation/presentation/cubit/image_generation_cubit.dart`
- Modify: `lib/features/image_generation/presentation/widgets/image_generation_status_panel.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input.dart`
- Modify: `test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`
- Modify: `test/features/image_generation/presentation/widgets/image_generation_controls_test.dart`

- [ ] **Step 1: Write failing synchronization and label tests**

Assert that `ImageGenerationState.profile` is always populated, initialization
resolves that profile, `refreshForSelectedModel()` releases the old engine and
rechecks availability, and the status panel displays `Stable Diffusion 1.5 Q4`
instead of any SDXS literal when that profile is active.

- [ ] **Step 2: Run presentation tests and verify RED**

```bash
rtk flutter test test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart test/features/image_generation/presentation/widgets/image_generation_controls_test.dart
```

Expected: FAIL because state and widgets are not profile-aware.

- [ ] **Step 3: Synchronize cubit state with the global selection**

Inject `ImageModelSelectionCubit`, add the selected profile to
`ImageGenerationState`, and implement:

```dart
Future<void> refreshForSelectedModel() async {
  cancelGeneration();
  await _actions.releaseEngine();
  emit(ImageGenerationState(profile: _selection.state.selectedProfile));
  await initialize();
}
```

Extend the actions API only with the `releaseEngine()` delegation required by
this flow. Initialization, installation, removal, and failure states retain the
captured profile.

- [ ] **Step 4: Make every status label dynamic**

Replace hard-coded names and sizes in the status panel with `state.profile`.
For external profiles, show `Locate again` semantics through Settings rather
than a Download action. For experimental models, include the 4 GB warning in
the install subtitle. Keep existing progress percentages and cancellation.

- [ ] **Step 5: Run all image and Settings tests**

```bash
rtk flutter test test/features/image_generation test/features/setting/presentation/image_model_settings_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Run repository verification**

```bash
rtk dart format --output=none --set-exit-if-changed lib test
rtk flutter analyze
rtk flutter test
rtk flutter build apk --release
```

Expected: formatting check, analysis, tests, and release APK build all succeed.
If a Pixel 6 is connected, also run:

```bash
rtk adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Expected: `Success`.

- [ ] **Step 7: Commit**

```bash
rtk git add lib/features/image_generation lib/features/chat/presentation/widgets/chat_input.dart test/features/image_generation
rtk git commit -m "feat(chat): use selected image model"
```

- [ ] **Step 8: Push the completed commit series**

```bash
rtk git status --short
rtk git push origin main
```

Expected: clean status and `main` updated with all feature commits.
