# Nomi Multimodal Assistant Design

## Scope and approved decisions

Nomi becomes an Android-first, local-first multimodal assistant that remains usable on arm64 devices with 4 GB RAM. The user approved a specialized-runtime architecture, explicit Image composer mode, hands-free voice mode, turn-scoped document attachments with optional workspace indexing, and confirmed rather than automatic cloud fallback.

The primary UI follows a compact ChatGPT-like layout. This program improves the existing product incrementally; it does not replace BLoC/GetIt, the Genkit chat path, Whisper, or workspace RAG.

## Product decomposition

The work is delivered as independently testable sub-projects:

1. Chat runtime reliability and UX.
2. Turn attachments and workspace handoff.
3. Hands-free voice hardening and resource coordination.
4. Stable Diffusion explicit Image mode.
5. Confirmed remote fallback and Android acceptance.

Each sub-project must leave the app usable and keep the full analyzer/test gate green.

## Architecture

`LocalAiRuntimeCoordinator` arbitrates heavyweight on-device work. On the Android 4 GB profile it grants one exclusive lease across local chat, Whisper transcription, and diffusion. Workspace RAG remains available because its current embedding model is comparatively small; operations are still serialized where they contend for CPU.

Existing provider-neutral boundaries remain authoritative:

- `LocalModelRuntime` owns chat-model preparation, cancellation, and disposal.
- `SpeechToText` remains backed by `whisper_ggml_plus`.
- `WorkspaceRagBackend` remains backed by `mobile_rag_engine`.
- A new `ImageGenerationService` owns diffusion availability, model preparation, progress, cancellation, generation, and disposal.
- A new attachment-preparation service turns selected files into app-owned attachment entities and model-ready turn content.

GetIt wires the coordinator and feature services. Widgets consume cubits and app-owned value types only.

## Chat runtime and model switching

Model switching becomes a typed state machine rather than a boolean. States include idle, stopping the prior generation, unloading the prior runtime, loading the target, ready, and failed. Each operation carries an operation id so a superseded warm-up cannot clear or overwrite a newer switch. For a local target, selection is transactional: the app cancels and joins current work, prepares the target, then persists the new selection. If preparation fails, the previous selection remains active and its runtime can be restored.

The existing conversation stays visible while switching. The composer is disabled with a compact status surface naming the target model; a full-screen blank loader is avoided. Failure restores a usable state and offers retry or another model. A local model is warmed exactly once per accepted selection. Remote models become ready without a native warm-up.

Streaming keeps the existing generation serial and cancellation semantics. Before the first token the assistant row shows a lightweight activity indicator; after the first token it renders incremental Markdown. Auto-scroll follows the stream only while the reader is close to the bottom.

## Composer and attachments

The composer has explicit Text and Image modes. Text mode accepts text, microphone input, images, and supported document files. Image mode accepts an image prompt and diffusion settings exposed by the selected preset.

Attachments use typed draft state and can be removed before send. Images are sent as model media only when the selected model supports them. Documents are parsed in a worker/service boundary and included in the current turn with filename/source markers. An explicit secondary action copies/indexes a document into the active workspace; merely attaching a document never changes workspace RAG.

The first document set is PDF, DOCX, TXT, Markdown, CSV, JSON, and common source-code/text files. Unsupported types, oversize content, missing files, and extraction failures produce actionable per-attachment states.

## Hands-free voice

The existing full-screen voice route remains the direct-audio experience. Silero VAD captures one utterance, Whisper transcribes it, the transcript goes through the normal chat pipeline, and TTS begins when complete sentence chunks arrive. The microphone and TTS never run together. Speaking over TTS triggers barge-in, cancels output, and returns to listening.

Voice mode acquires coordinator leases for transcription and local generation. Recoverable STT/generation/TTS failures are surfaced briefly and return to listening. Exiting invalidates every in-flight continuation and disposes temporary audio.

## Image generation

Image generation uses `llamadart`'s opt-in stable-diffusion.cpp runtime after an officially compatible `llamadart`/`genkit_llamadart` dependency set is available or a narrowly tested temporary adapter is established.

SDXS 512 Q8 is the Android default. Its model downloads on demand, resumes safely, verifies size/checksum where pinned, and can be removed. The runtime checks device capability and memory before load. Diffusion acquires an exclusive lease, unloads local chat and Whisper, generates into app-private storage, disposes, then allows chat to reload lazily.

The generated PNG is persisted as an assistant image message using the existing `Messages.kind` and `Messages.mediaPath` fields. Generation exposes phase progress and cancellation. Image mode is explicit, so diffusion is never invoked inside an active Genkit tool loop.

## Remote fallback

Eligible local failures create a fallback proposal; they never immediately contact a remote provider. The confirmation names the destination provider/model and lists whether text, images, or documents will leave the device. Declining keeps the draft/conversation local. Accepting retries the same turn through the selected remote model without duplicating the stored user message.

## Error and lifecycle policy

- Cancellation is normal control flow, not an error toast.
- Model/download/file/runtime errors are translated into stable app-owned categories.
- Every long operation exposes loading or progress and remains cancellable where the backend supports it.
- Backgrounding cancels unsafe foreground work and releases heavy runtimes under memory pressure.
- A failed optional subsystem does not make existing text chat unusable.

## Testing and acceptance

Every state machine and provider boundary receives unit tests for success, cancellation, supersession, and primary failure. Model-switch/stream/composer/confirmation states receive widget tests. Native smoke tests validate real GGUF, Whisper, and SDXS behavior separately from the normal suite.

The Android acceptance matrix includes 4 GB and 6+ GB profiles. The 4 GB profile must serialize chat/STT/diffusion, reject unsafe loads before OOM, retain the conversation, and recover to text chat after cancellation or failure.

Automated completion requires `rtk flutter analyze` and `rtk flutter test`. Hardware-only claims remain explicitly marked for manual verification until exercised on a target device.
