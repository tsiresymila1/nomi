# Voice Production Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Android-first voice support for 4 GB devices with selectable Whisper models, foreground/resumable provisioning, common audio-file attachments, and release-device evidence.

**Architecture:** Preserve BLoC/GetIt and the existing `SpeechToText` boundary. A focused Whisper model manager owns the persisted `tiny`/`base` choice and reuses `ModelBackgroundDownloadService` for Android foreground progress; `WhisperSpeechToText` only loads the selected, already-provisioned model. Audio attachments are converted to 16 kHz mono WAV by the Whisper companion converter, transcribed through the same coordinated STT service, and persisted as typed attachments whose transcript is sent as text context.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, flutter_bloc/hydrated_bloc, GetIt, background_downloader, whisper_ggml_plus 1.5.2, whisper_ggml_plus_ffmpeg 1.0.0, flutter_test

---

### Task 1: Persist a 4 GB-safe Whisper profile

**Files:**
- Create: `lib/features/chat/data/models/whisper_model_profile.dart`
- Create: `lib/features/chat/presentation/cubit/whisper_model_cubit.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`
- Modify: `lib/features/setting/presentation/setting_page.dart`
- Test: `test/features/chat/presentation/cubit/whisper_model_cubit_test.dart`
- Test: `test/features/setting/presentation/whisper_model_settings_test.dart`

**Target API:**

```dart
enum WhisperModelProfile {
  tiny('tiny', 'Tiny', 'ggml-tiny.bin'),
  base('base', 'Base', 'ggml-base.bin');

  const WhisperModelProfile(this.id, this.label, this.fileName);
  final String id;
  final String label;
  final String fileName;
}

class WhisperModelCubit extends HydratedCubit<WhisperModelState> {
  WhisperModelCubit() : super(const WhisperModelState());
  void selectProfile(WhisperModelProfile profile) =>
      emit(state.copyWith(profile: profile));
}
```

- [ ] Write a failing cubit test proving the default profile is multilingual `tiny`, persisted JSON restores the choice, and switching to `base` changes state only after an explicit action.
- [ ] Run `rtk flutter test test/features/chat/presentation/cubit/whisper_model_cubit_test.dart` and verify the missing types fail the test.
- [ ] Add `WhisperModelProfile { tiny, base }` with stable IDs, GGML filenames, Hugging Face URLs, labels, and a safe parser that falls back to `tiny`.
- [ ] Add a hydrated `WhisperModelCubit` exposing `selectProfile`, register it once through GetIt, and inject it where STT is created.
- [ ] Write a failing widget test proving Settings shows both profiles, labels `tiny` as recommended for 4 GB, and confirms before selecting `base`.
- [ ] Add the Voice & audio settings section with the selection confirmation and accessible loading/error/status text.
- [ ] Run both focused tests, `rtk flutter analyze lib test`, and commit as `feat(voice): add selectable Whisper profiles`.

### Task 2: Provision Whisper through the foreground downloader

**Files:**
- Create: `lib/features/chat/data/services/whisper_model_provisioner.dart`
- Modify: `lib/features/chat/data/services/whisper_speech_to_text.dart`
- Modify: `lib/features/chat/data/services/speech_to_text_factory.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`
- Modify: `lib/features/chat/presentation/cubit/whisper_model_cubit.dart`
- Modify: `lib/features/setting/presentation/setting_page.dart`
- Test: `test/features/chat/data/services/whisper_model_provisioner_test.dart`
- Test: `test/features/chat/data/services/whisper_speech_to_text_test.dart`

**Target API:**

```dart
abstract interface class WhisperModelDownloadClient {
  Future<DownloadedModelFile> download({
    required WhisperModelProfile profile,
    required void Function(double progress, String message) onProgress,
  });
  Future<bool> cancel(WhisperModelProfile profile);
}

class WhisperModelProvisioner {
  Future<String> ensureReady(
    WhisperModelProfile profile, {
    void Function(double progress, String message)? onProgress,
  });
  Future<bool> isInstalled(WhisperModelProfile profile);
  Future<bool> cancel(WhisperModelProfile profile);
}

abstract interface class WhisperEngine {
  Future<String> transcribe({
    required WhisperModelProfile profile,
    required String audioPath,
    required String language,
  });
}
```

- [ ] Write failing provisioner tests proving an installed file is reused, a missing model is downloaded with progress, the completed file is atomically moved to `WhisperController.getPath`, a retry reuses the background task, and cancellation is delegated.
- [ ] Run the provisioner test and confirm it fails because the service is missing.
- [ ] Define an app-owned `WhisperModelDownloadClient` seam wrapping `ModelBackgroundDownloadService.downloadModelToFile`, `watchTasks`, and `cancelDownload`.
- [ ] Implement `WhisperModelProvisioner.ensureReady(profile, onProgress:)`, `isInstalled`, and `cancel`; never call `consolidateHttpClientResponseBytes` or the plugin downloader.
- [ ] Write failing STT tests using fake provisioner/engine objects to prove selected-profile changes invalidate readiness and transcription cannot start before provisioning completes.
- [ ] Refactor `WhisperSpeechToText` behind a small `WhisperEngine` adapter; resolve the current cubit profile at each turn, provision it, and transcribe with that exact enum.
- [ ] Surface queued/running/paused/failed progress in `WhisperModelCubit` and Settings; keep foreground notification behavior owned by the shared downloader.
- [ ] Run focused tests, `rtk flutter analyze lib test`, and commit as `feat(voice): provision Whisper in foreground`.

### Task 3: Accept and transcribe audio attachments

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `lib/features/chat/data/models/chat_attachment.dart`
- Modify: `lib/features/chat/data/services/chat_attachment_preparation_service.dart`
- Modify: `lib/features/chat/data/services/chat_thread_actions_service.dart`
- Modify: `lib/features/chat/data/services/genkit_chat_helpers.dart`
- Modify: `lib/features/chat/data/services/chat_thread_context_service.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`
- Modify: `lib/features/chat/presentation/cubit/chat_input_cubit.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_input_attachment_preview_list.dart`
- Modify: `lib/features/chat/presentation/widgets/chat_bubble.dart`
- Test: `test/features/chat/data/services/chat_attachment_preparation_service_test.dart`
- Test: `test/features/chat/data/services/genkit_chat_helpers_test.dart`
- Test: `test/features/chat/presentation/widgets/chat_input_attachment_preview_list_test.dart`
- Test: `test/features/chat/presentation/widgets/chat_bubble_attachments_test.dart`

**Target behavior:**

```dart
enum ChatAttachmentKind { image, document, audio }

const supportedAudioExtensions = <String>{
  'wav',
  'mp3',
  'm4a',
  'aac',
  'flac',
  'ogg',
  'opus',
};

// Audio stays a typed persisted attachment; only its transcript enters the
// language-model prompt, bounded by maxTurnDocumentCharacters.
PreparedChatAttachment(
  kind: ChatAttachmentKind.audio,
  sourceType: extension,
  appPath: copied.path,
  extractedText: transcript,
);
```

- [ ] Add failing preparation tests for WAV, MP3, M4A, AAC, FLAC, OGG, and OPUS: each becomes `ChatAttachmentKind.audio`, is copied to app storage, transcribed via the injected `SpeechToText`, and stores a bounded transcript; blank transcription fails with an actionable attachment error.
- [ ] Add failing prompt/context tests proving an audio transcript is emitted with explicit `BEGIN AUDIO TRANSCRIPT` markers and counted as text tokens, never as model-native audio media.
- [ ] Run focused tests and confirm failures are caused by the absent audio kind/extensions.
- [ ] Add `whisper_ggml_plus_ffmpeg: ^1.0.0`, register `WhisperFFmpegConverter` at native startup, and run `rtk flutter pub get`.
- [ ] Extend the attachment preparer with injected `SpeechToText`, audio extension detection, transcription after the app-owned copy, transcript bounds, and cleanup on failure.
- [ ] Add audio extensions to the picker, audio icons/status to draft and persisted chips, and keep “Add to workspace” restricted to documents.
- [ ] Include persisted audio transcripts in Genkit history and local token-budget estimation while preserving existing image/document behavior.
- [ ] Run focused tests, `rtk flutter analyze lib test`, and commit as `feat(chat): transcribe audio attachments`.

### Task 4: Android 4 GB release qualification

**Files:**
- Modify: `docs/autopilot/memory.md`

- [ ] Run `rtk flutter test` and require every test to pass.
- [ ] Run `rtk flutter analyze lib test` and require zero issues.
- [ ] Run `rtk flutter build apk --release --target-platform android-arm64` and record APK size before/after the audio converter.
- [ ] Install the release APK on the connected Android device, launch it, grant microphone permission, and capture `adb shell dumpsys meminfo` at idle and during the voice flow when feasible.
- [ ] Smoke-check Settings profile selection, foreground Whisper download status, dictation, hands-free entry/exit, and audio attachment preparation. Mark any step that requires spoken input as hardware/manual evidence rather than claiming it from unit tests.
- [ ] Record measured results and remaining device-only checks in `docs/autopilot/memory.md`.
- [ ] Run `rtk git diff --check`, commit as `docs(android): record voice qualification`, push `main`, and monitor the Android APK workflow through artifact upload.
