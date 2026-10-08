# Nomi multimodal assistant test strategy

> Owns: coverage classes, risk scenarios, expected checks, verification gaps.

## What must be tested

- Unit: runtime state machines, generation serial/cancellation, lease exclusivity, attachment validation/preparation, fallback eligibility, download/checksum logic, and voice phase transitions.
- Widget: model-switch loader/error/retry, streaming Markdown transitions, composer modes, attachment previews, cloud confirmation, voice phases, image progress/cancel/result.
- Integration: local model switch then send; remote switch then stream; image/document turn; hands-free voice turn; diffusion generation then chat reload.
- Persistence: stored text/image/attachment messages render after database reopen.
- Native smoke: real GGUF load/stream/cancel, Whisper transcription, and SDXS generation on supported Android arm64.

## Risk scenarios

- Rapidly select two models while generation/warm-up is active.
- Cancel before first token, during streaming, during Whisper, and during diffusion.
- User scrolls upward while streaming; the UI must not force-scroll them to the bottom.
- Missing/corrupt model, projector, attachment, RAG embedder, or diffusion checkpoint.
- App backgrounds or loses memory during a heavy operation.
- 4 GB profile refuses an unsafe concurrent load and recovers without losing conversation.
- Local failure followed by decline/accept of remote fallback.
- Voice barge-in during TTS and blank/noisy Whisper results.

## Expected gates per task class

- Pure service/cubit: `rtk flutter test <focused-test-files> && rtk flutter analyze`.
- Widget/UI: focused widget tests plus `rtk flutter analyze`.
- Database/model: focused migration/serialization tests, build_runner when annotated sources change, then analyzer.
- Dependency/native runtime: `rtk flutter pub get && rtk flutter analyze && rtk flutter test`, followed by Android debug/release build when native packaging changes.
- Repository gate after every task: `rtk flutter analyze && rtk flutter test`.
- Physical-device-only acceptance is documented as manual verification, never faked as a green automated gate.
