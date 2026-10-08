# Chat Runtime Reliability And UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Android chat model switching deterministic and non-disruptive, then harden streamed Markdown and recovery UX before adding new multimodal engines.

**Architecture:** Preserve the current BLoC/GetIt and `LocalModelRuntime` boundaries. Replace the boolean model-switch flag with immutable typed state carrying phase, operation identity, model metadata, and failure detail. `ChatPageActions` owns the complete switch transaction; background warm-up receives its own operation and stale completions cannot clear a newer one. The chat remains mounted while a compact status surface disables only actions that would conflict with runtime loading.

**Tech Stack:** Flutter, Dart, flutter_bloc, GetIt, Genkit/llamadart runtime boundary, flutter_test

---

### Task 1: Serialize Local Runtime Preparation And Reset

**Files:**
- Modify: `lib/features/chat/data/services/local_model_runtime.dart`
- Modify: `test/features/chat/data/services/local_model_runtime_test.dart`

- [ ] Write failing tests proving concurrent prepares for the same key share one load.
- [ ] Write failing tests proving a later model request cannot be overwritten by an earlier delayed load.
- [ ] Write failing tests proving reset is serialized with prepare and disposes every superseded load exactly once.
- [ ] Implement a serialized/in-flight-deduplicated `CachingLocalModelRuntime` without changing its public boundary.
- [ ] Run `rtk flutter test test/features/chat/data/services/local_model_runtime_test.dart`, then `rtk flutter analyze` and `rtk flutter test` as the task boundary gate.

### Task 2: Ship Typed Transactional Model Switching Atomically

**Files:**
- Modify: `lib/features/chat/presentation/cubit/chat_ui_cubits.dart`
- Modify: `lib/features/chat/data/services/chat_page_actions_service.dart`
- Modify: `lib/features/chat/presentation/chat_page.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_app_bar.dart`
- Modify: `test/features/chat/presentation/cubit/chat_ui_cubits_test.dart`
- Modify: `test/features/chat/data/services/chat_page_actions_remote_only_test.dart`
- Create: `test/features/chat/data/services/chat_page_actions_model_switch_test.dart`
- Create: `test/features/chat/presentation/chat_page_model_loading_test.dart`

- [ ] Replace the boolean state with `ChatModelSwitchState` and `ChatModelSwitchPhase` (`idle`, `stoppingGeneration`, `unloading`, `loading`, `ready`, `failed`).
- [ ] Add operation identity, optional model ID/name/error, and stale-operation-safe `begin`, `advance`, `complete`, and `fail` transitions.
- [ ] Add fakes for selected models, active model resolution, runtime preparation/reset, and stopped generation.
- [ ] Write a failing test proving `selectModel` progresses through stop, reset, prepare, and selection, and reaches ready only after preparation.
- [ ] Write a failing test proving a failed prepare emits a typed failure while preserving/restoring the previous selected model.
- [ ] Write a failing test proving a stale background warm-up cannot clear a newer user-initiated switch.
- [ ] Make explicit local selection transactional: prepare the target before persisting it, and restore the previous runtime if target preparation fails.
- [ ] Keep chat/workspace entry warm-up background-only, but assign it an operation ID and suppress stale completions.
- [ ] Ensure remote selection skips local preparation and completes cleanly.
- [ ] Write a widget test proving the existing `ChatView` remains in the tree while a model is preparing.
- [ ] Write a widget test proving composer actions are disabled, not removed, while busy.
- [ ] Replace the full-screen loader with a compact animated status banner showing the typed phase and target model.
- [ ] Retain the previous conversation and scroll position across a switch.
- [ ] Add `ChatPageActions.retryLastModelSwitch()`: resolve the failed target from the repository by state model ID and rerun the transaction; the widget only invokes this action.
- [ ] Surface the retryable failure state without blocking model re-selection.
- [ ] Run the focused cubit/action/widget tests, then `rtk flutter analyze` and `rtk flutter test` so no typed-state consumer is left broken between tasks.

### Task 3: Harden Streaming Markdown And Scroll Behavior

**Files:**
- Modify: `lib/features/chat/presentation/widgets/chat_view.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_bubble.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input.dart`
- Modify: `lib/features/chat/presentation/cubit/chat_ui_cubits.dart`
- Modify: `lib/features/chat/data/services/chat_thread_actions_service.dart`
- Modify: `lib/features/chat/data/services/chat_runtime_helpers.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`
- Create: `test/features/chat/presentation/widgets/chat_view_streaming_test.dart`
- Create: `test/features/chat/data/services/chat_thread_retry_test.dart`
- Modify: `test/features/chat/data/services/chat_runtime_helpers_test.dart`

- [ ] Write tests for the empty streaming placeholder, partial Markdown, stop action, and final persisted message.
- [ ] Add a typed `ChatGenerationFailureCubit` containing the chat ID, failed user-message ID, safe display error, and retry eligibility.
- [ ] Make `storeUserMessage()` return the inserted message ID and cover that contract in `chat_runtime_helpers_test.dart`; never infer the row with a race-prone latest-message query.
- [ ] Split assistant generation from user-message persistence so `retryLastFailedGeneration()` regenerates from the existing failed turn and never inserts the user row twice.
- [ ] Auto-follow streaming only when the user is already near the bottom; show a jump-to-latest control otherwise.
- [ ] Throttle scroll animation updates so every token does not enqueue a new animation.
- [ ] Keep partial Markdown rendering stable and preserve selection/copy behavior.
- [ ] Expose a clear stop action while generating and a retry affordance after a recoverable generation failure.
- [ ] Register the failure cubit through the existing chat GetIt module, run the focused widget/service tests, then `rtk flutter analyze` and `rtk flutter test` as the task boundary gate.

### Task 4: Verify The First Android Chat Slice

**Files:**
- Modify only files already listed if verification exposes a regression.

- [ ] Run `rtk dart format` only on the files changed by Tasks 1–3 and confirm no unrelated path changes.
- [ ] Run `rtk flutter analyze`.
- [ ] Run `rtk flutter test`.
- [ ] Run `rtk git diff --check`.
- [ ] Review for cancellation, stale operation, and GetIt lifecycle regressions.
- [ ] Record remaining physical Android 4 GB checks in `docs/autopilot/memory.md`.
