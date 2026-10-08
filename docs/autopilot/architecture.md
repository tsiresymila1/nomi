# Nomi multimodal assistant architecture

> Owns: stable module layout, runtime ownership, provider wiring, service boundaries, data-flow shape, top-level file/folder responsibility.

## Module layout

- `core/local_ai`: Android-aware heavyweight runtime coordination, lease state, and memory policy.
- `features/chat/data/services`: chat generation, model lifecycle, attachment preparation, remote fallback proposal, STT/TTS bridges.
- `features/chat/presentation`: chat/voice cubits and small stateless widgets for composer, messages, loaders, confirmations, and voice phases.
- `features/downloads`: all catalog/download/install/remove operations for chat and auxiliary models.
- `features/workspace`: durable RAG documents and provider-neutral workspace search.
- `features/image_generation`: diffusion model descriptor/installer, app-facing service, cubit, and explicit Image composer flow.

## Boundaries (what may import what)

- UI imports app-owned cubits/entities/contracts, not native runtime packages.
- Native implementations may import `llamadart`, Whisper, or RAG packages but translate all results/errors into app-owned types.
- Chat may request workspace retrieval through `WorkspaceRagActions`; workspace never imports chat presentation.
- Image generation returns a saved file path and metadata; chat persists it as an image message through existing message services.
- The coordinator depends only on callbacks/contracts for cancellation and disposal, never feature widgets.

## Provider / service wiring

- GetIt remains the composition root. Feature registration functions own their services/cubits and guard duplicate registrations.
- `LocalModelRuntime` keeps one prepared chat model and disposes it when the selected model/context/projector changes.
- Model switching is transactional: stop/join current work, release the previous runtime, prepare the target, then persist selection. A failed target load retains/restores the previous selection.
- `SpeechToText` remains Whisper-backed; `WorkspaceRagBackend` remains `mobile_rag_engine`-backed for this program.
- `ImageGenerationService` uses `llamadart` image APIs only after a compatible `llamadart`/`genkit_llamadart` dependency pair is proven.
- `LocalAiRuntimeCoordinator` is a lazy singleton injected into chat, STT, and image services.

## Data flow

1. The composer prepares text and attachments, validates the selected model capability, and persists the user turn.
2. Workspace RAG optionally retrieves relevant chunks before generation.
3. The selected local/remote model streams through the existing Genkit path into draft cubits.
4. `ChatView` renders stored messages plus ephemeral thinking/tool/text draft rows.
5. Voice mode feeds VAD segments to Whisper, sends transcripts through the same chat path, and speaks sentence chunks from the streamed response.
6. Image mode acquires an exclusive diffusion lease, unloads chat/STT if necessary, generates and saves a PNG, disposes diffusion, persists an image message, and lets chat reload lazily.
7. If local generation fails with an eligible resource/runtime error, a fallback proposal is shown. Remote execution starts only after confirmation.
