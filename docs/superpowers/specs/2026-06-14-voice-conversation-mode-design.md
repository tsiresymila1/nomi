# Hands-Free Voice Conversation Mode (ChatGPT-style) — Design

## Goal

A continuous, hands-free voice conversation: the user taps once to enter voice
mode, speaks, and the app automatically detects end-of-speech, transcribes,
sends the message, generates the reply, **speaks it aloud**, then returns to
listening — looping until the user exits. Like ChatGPT's voice mode.

This composes the existing on-device pieces (Whisper STT, flutter_tts TTS, the
`record` recorder, and the normal chat send/generate path) into one orchestrated
loop with a dedicated full-screen UI. The current manual controls (hold-to-record
mic in the input, per-message speak button) stay unchanged.

## State machine

`VoiceConversationCubit` drives one loop:

```
idle → listening → (silence detected) → transcribing → sending/thinking
     → speaking → listening → … (repeat)   |  any state → idle (user exits)
```

- **listening**: recorder active; show live mic level. Auto-stop on sustained
  silence (see VAD). A manual "tap to stop now" also ends listening.
- **transcribing**: stop recorder → Whisper `transcribe(wav)`. Empty/blank
  transcript → return to listening (no send).
- **sending/thinking**: `ChatThreadActions.sendMessage(text)`; wait for the
  assistant reply to finish (observe `ChatGeneratingCubit` false + final draft /
  last assistant message).
- **speaking**: `TextToSpeech.speak(finalReplyText)`; on `speakingChanges=false`
  → back to listening.
- **barge-in**: tapping the orb (or starting to speak) during `speaking`
  cancels TTS and returns to listening immediately.
- **exit**: closing the screen stops recorder + TTS + cancels any in-flight
  generation and returns to `idle`.

## End-of-speech detection (VAD)

- Use `record`'s amplitude stream (`AudioRecorder.onAmplitudeChanged(interval)`)
  to read mic level. Track a rolling level; when level stays below a threshold
  for a debounce window (e.g. ~1.5 s) after at least some speech was detected,
  auto-stop and transcribe.
- Guard: a max listen duration (e.g. 30 s) and a min speech duration so silence
  alone (user said nothing) loops without sending.
- `AudioRecorderService` gains an amplitude stream + the silence-detection helper
  (or a thin `VadController` wrapping it) — keep it injectable/fake-able.

## Speaking the reply

- v1: speak the **final** assistant text once generation completes (strip
  markdown — reuse `VoiceOutputCubit`'s stripper).
- Future upgrade (noted, not built): sentence-by-sentence streaming TTS as the
  reply streams, for lower latency.

## UI

- Full-screen `VoiceConversationPage` (pushed from a voice-mode button in the
  chat input / app bar, shown only when `supportsSpeechToText`).
- Center: an animated orb/waveform whose state/anim reflects
  listening / thinking / speaking (reuse `flutter_animate`). Live partial
  transcript text. A large stop/close button. Optional mute.
- Tapping the orb: stop-listening-now during listening; barge-in (cancel TTS)
  during speaking.
- The conversation still writes to the normal chat thread (messages persist), so
  exiting voice mode shows the transcript as a normal chat.

## Architecture

`lib/features/chat/presentation/`:
- `cubit/voice_conversation_cubit.dart` — the state machine above; depends on
  `SpeechToText`, `TextToSpeech`, the recorder/VAD, `ChatThreadActions`, and the
  generation-state cubits (`ChatGeneratingCubit`, `ChatDraftResponseCubit` / a
  way to read the final assistant message). Emits a `VoiceConversationState`
  (phase enum + partial transcript + level). Fully testable with fakes.
- `voice_conversation_page.dart` + widgets (orb, transcript, controls).

Reuse, do not duplicate: `SpeechToText`, `TextToSpeech`, `AudioRecorderService`
(extended with amplitude/VAD), `VoiceOutputCubit`'s markdown stripper (extract
the stripper to a shared helper so both use it), `ChatThreadActions.sendMessage`.

## Capability / platform

- Gate the voice-mode entry on `AppCapabilities.current.supportsSpeechToText`
  (native). TTS availability is separate (`supportsTextToSpeech`); if TTS is
  unavailable the loop still works but skips speaking.
- Mic permission already handled by the recorder; request on entry, deny → toast
  + exit.

## Error handling

- STT failure → toast, return to listening (don't crash the loop).
- Generation failure → toast, return to listening.
- TTS failure → skip speaking, return to listening.
- Exit always tears down recorder + TTS + generation cleanly (no leaked mic/audio).

## Testing (analyze + unit only — no device)

- `VoiceConversationCubit` with fakes for STT/TTS/recorder/VAD/send:
  - listening → (silence) → transcribe → send → thinking → speak → listening loop
    advances through the expected phases.
  - blank transcript loops back to listening without sending.
  - barge-in during speaking cancels TTS → listening.
  - exit tears everything down (stop called on recorder + TTS).
  - STT/generation/TTS errors return to listening (or idle) without throwing.
- VAD/silence helper: emits stop after the debounce window of sub-threshold
  levels following detected speech; never stops on pure silence with no speech.

## Sequencing

1. Extract the markdown stripper to a shared helper (used by VoiceOutputCubit +
   voice mode).
2. Add amplitude/VAD to `AudioRecorderService` (+ a `VadController` + tests).
3. `VoiceConversationCubit` state machine (+ tests with fakes).
4. Full-screen UI (orb/transcript/controls) + entry button.
5. DI wiring + capability gating.
6. Device verification (deferred to user).

## Risks

- VAD tuning (threshold/debounce) is device/mic dependent — expose constants,
  keep a manual "stop listening" fallback so it's usable even if VAD is off.
- Echo: TTS output could be picked up by the mic if listening overlaps speaking —
  ensure strictly sequential phases (listen only after speaking completes); no
  full-duplex in v1.
- Latency: local STT + local model + TTS in series can feel slow on low-end
  devices; surface clear "thinking…" state.
- Two audio subsystems (record + flutter_tts) must not run simultaneously —
  the state machine enforces this.
