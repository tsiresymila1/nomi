# Nomi multimodal assistant requirements

> Owns: product behaviour, user-visible requirements, API contracts, security/data rules, roles, permissions, external contracts, and the project's hard constraints (never-do).

## What the product must do

- Prioritize Android and remain usable on arm64 devices with 4 GB RAM.
- Provide reliable local and remote chat with fast, safe model switching.
- Stream assistant text incrementally and render partial/final Markdown without losing the draft.
- Accept text, microphone input, images, and common documents in a conversation.
- Send images directly to compatible multimodal models.
- Parse PDF, DOCX, TXT, Markdown, CSV, and code attachments for the current turn; expose a separate action to persist a document into workspace RAG.
- Provide a full-screen, hands-free voice conversation mode using VAD, Whisper, the normal chat path, and streaming TTS.
- Generate images locally through an explicit Image composer mode backed by stable-diffusion.cpp/llamadart.
- Persist text, Markdown, attachment, and generated-image messages so conversations survive restart.
- Offer remote fallback only after an explicit confirmation showing the destination model/provider and privacy implication.

## User-visible behaviour

- The primary screen is a compact ChatGPT-like conversation with the active model in the app bar and a single multimodal composer.
- Composer modes are Text and Image. Image mode is always user-selected; a chat model does not invoke diffusion inside an active tool loop.
- Model switching shows the target model and phase (`stopping`, `unloading`, `loading`, `ready`, `failed`) without destroying the visible conversation.
- Sending and model switching are mutually exclusive; cancellation is always available for generation, transcription, download, and image generation.
- Streaming shows a lightweight first-token loader, then incremental Markdown. Auto-scroll follows only while the user remains near the bottom.
- Attachments show removable previews, extraction/loading progress, type/size validation, and actionable errors.
- Voice mode automatically detects turns, transcribes, streams the answer, speaks complete sentence chunks, supports barge-in, and returns to listening after recoverable errors.
- On 4 GB devices the application serializes heavy local runtimes and explains short reload delays instead of crashing.
- Stable Diffusion starts with the SDXS 512 Q8 preset. Unsupported/low-memory devices get an availability explanation, not a crash.
- Generated images display in the chat, can be cancelled while generating, and remain available after app restart.

## API contracts

- Existing `LocalModelRuntime`, `SpeechToText`, `WorkspaceRagBackend`, `ChatThreadActions`, and native-tool approval contracts remain provider-neutral.
- A local runtime coordinator exposes exclusive cancellable leases for heavyweight operations and never grants overlapping chat, STT, and diffusion leases on constrained Android devices.
- Image generation exposes an app-owned service contract for availability, model preparation, progress, cancellation, generation, and disposal.
- Attachment preparation returns typed, persisted attachment metadata plus turn-scoped content/media parts; widgets never parse files directly.
- Remote fallback returns a proposal first and proceeds only after explicit confirmation.

## Security / data rules · roles · permissions

- Local content remains on device unless the user explicitly selects or confirms a remote model.
- A remote fallback confirmation names the provider and lists which text/attachments will leave the device.
- Mutating native tools keep their existing explicit approval flow.
- Model and runtime downloads use pinned sources, size checks, and SHA-256 when a stable digest is available.
- Never log secrets, document bodies, audio, images, or remote API tokens.
- Generated media lives in app-private storage unless the user explicitly exports it.

## Constraints (never do)

- Never add a second state-management framework; keep BLoC/HydratedBloc/GetIt.
- Never bypass chat generation serial/cancellation semantics.
- Never load chat and diffusion models concurrently on the Android 4 GB profile.
- Never automatically send local conversation data to a remote provider.
- Never rewrite existing Drift migration blocks; add incremental migrations only when required.
- Never hardcode secrets or edit `.env` autonomously.
- Never disable tests, weaken gates, or hide analyzer errors to finish a task.
- Never bundle multi-gigabyte model weights in the APK; download them on demand.
