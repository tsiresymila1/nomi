# Image Model Preloading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preload the selected image model before the user submits an image prompt and reuse the resident engine across chats.

**Architecture:** Add an idempotent preparation operation at the image service boundary, expose it through actions, and orchestrate it from the existing Bloc. Selection, installation, initialization, and Image-mode entry prepare the engine; generation retains only a defensive residency check.

**Tech Stack:** Flutter, flutter_bloc, local AI runtime coordinator, flutter_test

---

### Task 1: Add explicit engine preparation

**Files:**
- Modify: `lib/features/image_generation/data/services/local_image_generation_service.dart`
- Modify: `lib/features/image_generation/data/services/image_generation_actions.dart`
- Test: `test/features/image_generation/data/services/local_image_generation_service_test.dart`
- Test: `test/features/image_generation/data/services/image_generation_actions_test.dart`

- [ ] **Step 1: Write failing service tests**

Add tests that call `prepareModel`, assert that the selected installed path is
loaded and owns the diffusion lease, then generate and assert the backend load
count remains one. Add a missing-model test expecting `StateError`.

- [ ] **Step 2: Verify RED**

Run: `rtk flutter test test/features/image_generation/data/services/local_image_generation_service_test.dart`

Expected: compilation fails because `prepareModel` is not defined.

- [ ] **Step 3: Implement service and actions APIs**

Add `Future<InstalledImageModel> prepareModel()` to
`ImageGenerationServiceApi` and `ImageGenerationActionsApi`. In
`LocalImageGenerationService`, serialize resolution and `_ensureGenerator`, then
return the installed model. Delegate through `ImageGenerationActions`.

- [ ] **Step 4: Verify GREEN**

Run: `rtk flutter test test/features/image_generation/data/services/local_image_generation_service_test.dart test/features/image_generation/data/services/image_generation_actions_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit: `feat(image): add explicit model preloading`

### Task 2: Preload during lifecycle transitions

**Files:**
- Modify: `lib/features/image_generation/presentation/cubit/image_generation_cubit.dart`
- Test: `test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`
- Modify test fakes implementing `ImageGenerationActionsApi`

- [ ] **Step 1: Write failing cubit tests**

Assert that initialize preloads an installed model, installation emits
`loadingModel` before `ready`, selection refresh releases then preloads, and
generation emits `generating` without emitting `loadingModel`.

- [ ] **Step 2: Verify RED**

Run: `rtk flutter test test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`

Expected: assertions fail because the cubit never calls `prepareModel` and Send
still emits `loadingModel`.

- [ ] **Step 3: Implement lifecycle preloading**

Introduce a private prepare transition that emits `loadingModel`, calls the
actions layer, then emits `ready`. Use it from initialize and install. Keep
`refreshForSelectedModel` release-first behavior. Start `_generateTurn` in
`generating` instead of `loadingModel`.

- [ ] **Step 4: Verify GREEN**

Run: `rtk flutter test test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart test/features/setting/presentation/image_model_settings_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit: `feat(image): preload selected model lifecycle`

### Task 3: Surface preload state before Send

**Files:**
- Modify: `lib/features/chat/presentation/widgets/chat_input.dart`
- Modify: `lib/features/image_generation/presentation/widgets/image_generation_status_panel.dart`
- Modify: `lib/features/setting/presentation/widgets/image_model_settings_section.dart`
- Test: `test/features/image_generation/presentation/widgets/image_generation_controls_test.dart`
- Test: `test/features/setting/presentation/image_model_settings_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert that `loadingModel` without an active prompt is visible as preload state
in composer/settings, `ready` is labelled Ready, and generation-time activity
continues to live in the chat timeline.

- [ ] **Step 2: Verify RED**

Run: `rtk flutter test test/features/image_generation/presentation/widgets/image_generation_controls_test.dart test/features/setting/presentation/image_model_settings_test.dart`

Expected: tests fail because preload is currently hidden from the composer and
Settings does not label loading/ready residency.

- [ ] **Step 3: Implement preload UX**

Show a preparation card when `loadingModel` has no active prompt, show loading
progress in Settings, label a resident selection Ready, and request idempotent
initialization whenever Image composer mode is selected.

- [ ] **Step 4: Verify GREEN**

Run: `rtk flutter test test/features/image_generation/presentation/widgets/image_generation_controls_test.dart test/features/setting/presentation/image_model_settings_test.dart test/features/chat/presentation/widgets/chat_input_image_submission_test.dart`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit: `feat(image): show model preload readiness`

### Task 4: Full verification and delivery

- [ ] **Step 1: Format changed Dart files**

Run: `rtk dart format <changed Dart files>`

- [ ] **Step 2: Analyze and test**

Run: `rtk flutter analyze && rtk flutter test`

Expected: no analysis issues and all tests pass.

- [ ] **Step 3: Build Android release**

Run: `rtk flutter build apk --release`

Expected: `build/app/outputs/flutter-apk/app-release.apk` is produced.

- [ ] **Step 4: Commit verification record and push**

Mark this plan complete, commit the record, then run `rtk git push origin main`.
