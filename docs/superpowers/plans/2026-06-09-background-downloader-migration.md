# Background Downloader Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom model download task engine with persistent, cross-platform `background_downloader` tasks.

**Architecture:** Keep `ModelBackgroundDownloadService` as the app-facing boundary and translate `background_downloader` task updates into app-owned snapshot types. Configure persistent tracking and Android foreground execution inside the service, leaving model installation orchestration in `DownloadsCubit`.

**Tech Stack:** Flutter, Dart, `background_downloader`, `flutter_bloc`, `flutter_test`

---

### Task 1: Define App-Owned Download Types

**Files:**
- Create: `test/features/downloads/data/services/model_background_download_service_test.dart`
- Modify: `lib/features/downloads/data/services/model_background_download_service.dart`

- [ ] Write failing tests for stable task IDs, task metadata, storage location, authorization headers, and status mapping.
- [ ] Run `rtk flutter test test/features/downloads/data/services/model_background_download_service_test.dart` and verify the tests fail because the new helpers and snapshot types do not exist.
- [ ] Add app-owned download status/snapshot types and pure task-building helpers.
- [ ] Run the targeted test and verify it passes.

### Task 2: Replace the Download Engine

**Files:**
- Modify: `lib/features/downloads/data/services/model_background_download_service.dart`

- [ ] Initialize `FileDownloader` task tracking, notification configuration, Android foreground mode, and persistent task reconciliation.
- [ ] Replace `SmartBackgroundTasksController` task creation with `DownloadTask` enqueueing.
- [ ] Translate `TaskUpdate` and database records into app-owned snapshots.
- [ ] Preserve existing download, cancellation, duplicate prevention, and file result behavior.
- [ ] Run the targeted service test.

### Task 3: Reconnect App Integration

**Files:**
- Modify: `lib/features/downloads/presentation/cubit/downloads_cubit.dart`
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Podfile`

- [ ] Replace `SmartTaskSnapshot` and `SmartTaskStatus` usage with app-owned snapshot/status types.
- [ ] Add explicit `background_downloader` dependency and remove `smart_background_tasks`.
- [ ] Replace the custom Android foreground service declaration with WorkManager foreground data-sync configuration.
- [ ] Raise the iOS deployment target to 14.0.
- [ ] Run `rtk flutter pub get`.

### Task 4: Verify the Migration

**Files:**
- Verify: `test/features/downloads/data/services/model_background_download_service_test.dart`
- Verify: entire project

- [ ] Run the targeted service test.
- [ ] Run `rtk dart format` on changed Dart files.
- [ ] Run `rtk flutter analyze`.
- [ ] Run `rtk flutter test`.
- [ ] Inspect `rtk git diff --check` and `rtk git status --short`.
