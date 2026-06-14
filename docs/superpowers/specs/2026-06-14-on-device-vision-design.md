# On-Device Vision (Multimodal Local Models) — Design

## Goal

Let local models understand images on-device: attach/capture a photo (receipt,
document, scene) and have the selected local model describe or answer questions
about it — matching Off Grid's vision feature, but reusing the llamadart stack
gena already ships. No new inference engine.

## Why this is low-effort

The pieces already exist:

- `genkit_llamadart`'s `LlamaModelDefinition` accepts an **`mmprojPath`**
  (multimodal projector) — vision is a first-class, supported parameter.
- The chat path already builds Genkit **`MediaPart`** messages from stored image
  rows (`genkit_chat_service._buildGenkitMessages`), and `ModelInfo.supportImage`
  already gates image input in the UI.
- Image capture/attach already works (`image_picker`, camera source) and images
  are persisted to the app support dir.

The only missing wiring is: (1) provide the projector file to the runtime for
GGUF vision models, and (2) a capture-to-analyze UX affordance.

## Two model families

| Family | How vision works | gena change |
|---|---|---|
| **LiteRT-LM** (e.g. `gemma-3n-*` already in catalog, `supportImage: true`) | Vision is built into the bundle; no separate projector | Verify `MediaPart` reaches the litert_lm backend; likely works once images flow through |
| **GGUF** (SmolVLM2, Qwen2.5-VL, Gemma 3 vision) | Needs `model.gguf` **+** `mmproj.gguf` projector | Download + pass `mmprojPath` |

Start with the LiteRT-LM path (zero new download — `gemma3n` is already a
seeded multimodal model), then add GGUF+mmproj for the smaller SmolVLM option.

## Changes

### 1. Catalog + model metadata
- Add optional `mmprojUrl` (and `mmprojSize`) to `DefaultSeedModel` and a
  persisted `mmprojSource`/`mmprojPath` to `ModelInfo` + Drift (nullable column,
  schema bump, additive migration only).
- Seed one GGUF vision entry, e.g. `SmolVLM2-*-Instruct` GGUF + its
  `mmproj-*.gguf`, plus keep `gemma3n` (LiteRT-LM, no projector).

### 2. Download
- When installing a model with an `mmprojUrl`, the background downloader fetches
  both files into the app-support model dir (second `DownloadTask`, same group).
  Installation completes only when both exist.

### 3. Runtime wiring
- `LocalRuntimeRequest` gains `mmprojPath`.
- `LlamadartLocalModelRuntime._LlamadartRuntimeLoader.load` passes
  `mmprojPath: request.mmprojPath` into `LlamaModelDefinition` (currently unset →
  defaults null). Validate the projector file exists when the model declares one.
- Cache key already includes the model file; add `mmprojPath` to it.

### 4. Generation
- No change needed if `MediaPart` already flows; add a guard that rejects image
  input when the selected model is not `supportImage` with a clear message.

### 5. UX (capture-to-analyze)
- Add a camera/"analyze image" affordance in chat input (camera source already
  available via `image_picker`). Optional quick prompts: "Describe this image",
  "Extract the text", "What's on this receipt?".
- A dedicated full-screen capture → analyze flow can come later; v1 reuses the
  existing image-attach + a preset prompt.

## Capability / platform

- Gate behind `AppCapabilities.supportsLocalModels` (native only). Web stays
  remote-only; vision via remote multimodal models is a separate, later path.
- Memory: vision adds RAM pressure; keep the GGUF vision model small (SmolVLM2
  ~0.5–2B) and surface a device-tier note.

## Testing

- Unit: catalog has a valid vision model + projector URL pair (HTTP-verified by
  the existing `tool/verify_model_catalog.dart`, extended for mmproj).
- Unit: runtime passes `mmprojPath` through (fake loader asserts the request).
- Unit: image input rejected for non-`supportImage` models.
- Manual (device): attach a photo, confirm the local model describes it; switch
  to a text-only model and confirm image input is blocked with a clear message.

## Sequencing

1. Verify the LiteRT-LM (`gemma3n`) image path works end-to-end today (cheapest
   signal — may already function once an image is attached).
2. Add `mmprojPath` plumbing (request → definition) + cache key.
3. Add catalog vision GGUF entry + projector download.
4. Add capture-to-analyze UX + preset prompts.
5. Device verification.

## Risks

- `genkit_llamadart` / `llamadart_litert_lm_flutter` image handling for LiteRT-LM
  must be confirmed (the GGUF + `mmproj` path is the documented one).
- Projector/model version mismatch fails to load — pin known-good pairs and
  verify URLs like the text catalog.
- Larger memory footprint on low-end devices.
