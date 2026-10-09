# Image Generation Chat Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move image prompts and generation feedback into the chat timeline immediately while preserving retry, cancellation, and database consistency.

**Architecture:** Split an image turn into a durable user-message start and a generated assistant-image completion. Keep runtime progress transient in `ImageGenerationCubit` and render it at the end of `ChatView`, while leaving installation/readiness controls in the composer.

**Tech Stack:** Flutter, flutter_bloc, Drift, flutter_test

---

### Task 1: Persist the image prompt before generation

**Files:**
- Modify: `lib/features/image_generation/data/services/image_generation_actions.dart`
- Test: `test/features/image_generation/data/services/image_generation_actions_test.dart`

- [x] **Step 1: Write a failing data test**

Add a controllable generation future and assert that the user message is
already stored before that future completes. Update failure and cancellation
expectations so the user prompt remains and no assistant image is inserted.

- [x] **Step 2: Run the focused test and verify RED**

Run: `rtk flutter test test/features/image_generation/data/services/image_generation_actions_test.dart`

Expected: FAIL because the current action inserts the prompt only after image
generation succeeds.

- [x] **Step 3: Implement the minimal persistence split**

Introduce explicit `persistPrompt` control on `generateAndPersist`, defaulting
to `true`. Insert and title the user turn before invoking the image service;
insert only the assistant image after a successful result.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `rtk flutter test test/features/image_generation/data/services/image_generation_actions_test.dart`

Expected: all tests pass.

- [x] **Step 5: Commit**

Commit: `fix(image): persist prompts before generation`

### Task 2: Make generation state retry-safe

**Files:**
- Modify: `lib/features/image_generation/presentation/cubit/image_generation_cubit.dart`
- Test: `test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`

- [x] **Step 1: Write failing cubit tests**

Assert that loading, failure, and cancellation retain the normalized active
prompt. Add a retry test asserting the second generation call passes
`persistPrompt: false`.

- [x] **Step 2: Run the focused test and verify RED**

Run: `rtk flutter test test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`

Expected: FAIL because the state has no active prompt or retry API.

- [x] **Step 3: Implement active prompt and retry**

Add `activePrompt` to `ImageGenerationState`, route generation through a private
method accepting `persistPrompt`, and expose `retryGeneration()` for failed or
cancelled turns.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `rtk flutter test test/features/image_generation/presentation/cubit/image_generation_cubit_test.dart`

Expected: all tests pass.

- [x] **Step 5: Commit**

Commit: `feat(image): retain generation turn state`

### Task 3: Move generation feedback into the timeline

**Files:**
- Create: `lib/features/image_generation/presentation/widgets/image_generation_chat_activity.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_view.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input.dart`
- Test: `test/features/image_generation/presentation/widgets/image_generation_chat_activity_test.dart`
- Test: `test/features/image_generation/presentation/widgets/image_generation_controls_test.dart`

- [x] **Step 1: Write failing widget tests**

Cover loading, progress, failure/retry, and cancellation rendering for the new
timeline item. Add a visibility predicate test proving active generation is not
rendered by the composer status panel.

- [x] **Step 2: Run the focused tests and verify RED**

Run: `rtk flutter test test/features/image_generation/presentation/widgets`

Expected: FAIL because the timeline activity widget and visibility policy do
not exist.

- [x] **Step 3: Implement the timeline item and immediate composer clear**

Append `ImageGenerationChatActivity` to `ChatView` only for the selected chat
when the image cubit is loading, generating, failed, or cancelled. Clear the
text controller before awaiting generation. Keep only runtime setup phases in
the composer panel.

- [x] **Step 4: Run focused tests and verify GREEN**

Run: `rtk flutter test test/features/image_generation/presentation/widgets`

Expected: all tests pass.

- [x] **Step 5: Commit**

Commit: `fix(chat): show image generation in timeline`

### Task 4: Verify the complete change

**Files:**
- Review all files changed by Tasks 1-3

- [x] **Step 1: Format changed Dart files**

Run: `rtk dart format <changed Dart files>`

- [x] **Step 2: Run static analysis**

Run: `rtk flutter analyze`

Expected: no issues found.

- [x] **Step 3: Run all tests**

Run: `rtk flutter test`

Expected: all tests pass.

- [x] **Step 4: Build the Android release APK**

Run: `rtk flutter build apk --release`

Expected: release APK is produced successfully.

- [x] **Step 5: Push the commits**

Run: `rtk git push origin main`

Expected: `origin/main` advances to the verified implementation.
