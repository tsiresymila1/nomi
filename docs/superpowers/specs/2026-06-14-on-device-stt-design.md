# On-Device Voice Input (Whisper STT) — Design

## Goal

Hold-to-record voice input in chat: record speech, transcribe it on-device with
whisper.cpp, drop the text into the chat input. Fully offline, native-only —
matching Off Grid's core voice-input feature.

## Package choice

- **`whisper_ggml` ^1.7.0** — on-device whisper.cpp, iOS/Android/macOS (+Linux/
  Windows), CoreML on iOS, MIT. Resolves cleanly with the project's Dart 3.11
  (verified via `pub add --dry-run`; pulls `riverpod`/`state_notifier`
  transitively — internal to the plugin, no app coupling). API:
  `WhisperController().transcribe(model: WhisperModel.base, audioPath: wav, lang: 'auto')`,
  plus `downloadModel(model)` / `getPath(model)`. Input must be **16 kHz mono WAV**.
- **`record` ^6** — microphone capture; configure `RecordConfig(encoder:
  AudioEncoder.wav, numChannels: 1, sampleRate: 16000)` so output feeds whisper
  directly with no conversion.

Fallback if `whisper_ggml` misbehaves on a target: `whisper_ggml_plus`
(whisper.cpp 1.8.3, Metal/CoreML) — same `WhisperController.transcribe` API.

## Architecture (mirror the LocalModelRuntime / RAG pattern)

Provider-neutral boundary with a conditional factory, so web compiles and unit
tests run without native libs.

```
lib/features/chat/data/services/
  speech_to_text.dart                 # contract + result + fake-able driver
  whisper_speech_to_text.dart         # native: whisper_ggml + record
  unsupported_speech_to_text.dart     # web/unsupported: throws
  speech_to_text_factory.dart         # conditional export (if dart.library.io)
  audio_recorder_service.dart         # `record` wrapper -> 16kHz mono wav temp file
```

Contract:

```dart
abstract interface class SpeechToText {
  Future<void> ensureModelReady();              // download whisper model if absent
  Future<SttResult> transcribe(String wavPath, {String lang = 'auto'});
  bool get isAvailable;                          // capability + platform
}
class SttResult { final String text; final String? language; }
class SpeechToTextException implements Exception { final String message; }
```

Native impl owns a single cached `WhisperController`, lazy `downloadModel` on
first use (first-run download, like RagModelProvisioner — no bundled model).
Default `WhisperModel.base` (good accuracy/size); expose a settings option later.

## Capability / platform

- Add `supportsSpeechToText` to `AppCapabilities` — true on Android/iOS/macOS,
  false on web (and treat Windows/Linux as not-a-release-target like local models).
- Web: the unsupported impl throws; the mic button is hidden/disabled.

## Permissions / platform config

- iOS/macOS `Info.plist`: `NSMicrophoneUsageDescription`.
- Android `AndroidManifest.xml`: `RECORD_AUDIO` permission.
- Request mic permission at first record; deny → clear toast, no crash.
- macOS entitlements: audio-input.

## UX flow

1. Mic button in `chat_input` (next to send/attach), shown only when
   `AppCapabilities.current.supportsSpeechToText`.
2. Press-and-hold to record (waveform/timer affordance); release to stop.
3. On release: stop recorder → `transcribe(wav)` (spinner "Transcribing…") →
   insert text into `ChatInputCubit` (append to existing draft, not replace).
4. Cancel gesture (slide-to-cancel) discards the recording.
5. First use downloads the whisper model with a progress indicator; offline →
   clear error, mic disabled until model present.

## Data flow

`record` → temp `*.wav` (16kHz mono) → `SpeechToText.transcribe` → `SttResult.text`
→ `ChatInputCubit.appendText` → user edits/sends as a normal message. No new
persistence; the transcript is just input text.

## Testing

- Unit: `AppCapabilities.supportsSpeechToText` per platform (web false, native true).
- Unit: a fake `SpeechToText` driver — mic button hidden when unavailable;
  transcribe result appended to the input cubit; transcribe error surfaces a
  message and does not clear the draft.
- Unit: `audio_recorder_service` builds the expected 16kHz/mono/wav config
  (inject a fake `record` or assert the config object).
- Native transcription + model download are verified manually on device (cannot
  unit-test whisper.cpp / a real mic).

## Sequencing

1. Add `whisper_ggml` + `record`; platform permission config.
2. STT boundary + capability flag + unsupported impl + factory (+ tests).
3. `audio_recorder_service` (record → wav).
4. Native whisper impl (controller cache, first-run model download).
5. Mic button + record/transcribe UX in chat input.
6. Device verification (record → transcribe → insert) on iOS + Android.

## Risks

- Two native inference libs now coexist (llama.cpp + whisper.cpp) — larger app,
  watch iOS SPM/CocoaPods integration and build time.
- 16 kHz mono WAV is mandatory; wrong record config → garbage transcription.
- `whisper_ggml` last published ~9 months ago; if it breaks against the current
  toolchain, switch to `whisper_ggml_plus`.
- Model size: `base` ≈ 140 MB download (first-run, cached). Offer `tiny` (~75 MB)
  for low-end devices.
