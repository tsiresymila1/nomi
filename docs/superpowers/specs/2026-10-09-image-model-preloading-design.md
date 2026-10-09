# Image Model Preloading Design

## Goal

Load the globally selected image model when it is selected or installed, so
image prompts do not pay the model-loading cost after the user presses Send.

## Current behavior

The selection flow releases the previous engine and only checks whether the new
GGUF exists. `LocalImageGenerationService.generate` performs the actual backend
load through `_ensureGenerator`, so the first prompt in any chat waits for model
loading.

## Approaches considered

1. Preload through the image-generation service and cubit. This keeps loading
   serialized with generation, reuses the resident engine, and exposes loading
   state consistently. This is the selected approach.
2. Load directly from the Settings widget. This couples UI to the backend and
   misses restored selections and composer-mode recovery.
3. Listen to every selection change inside the selection cubit. This hides
   asynchronous failures inside persisted state management and complicates
   lifecycle ownership.

## Design

- Add an idempotent `prepareModel` operation to the service and actions layers.
  It resolves the selected GGUF, acquires the diffusion runtime lease, and loads
  the backend engine without generating an image.
- `ImageGenerationCubit.initialize` preloads an installed selected model before
  reporting `ready`.
- Installation preloads the downloaded model before reporting `ready`.
- Model switching releases the previous engine, changes the global profile,
  then initializes and preloads the new installed model.
- Entering Image composer mode requests the same idempotent preload. This
  restores the engine before typing/sending when Android previously evicted it
  for chat or Whisper.
- A generation turn starts directly in `generating`; it no longer presents a
  model-loading stage after Send. The service retains a defensive ensure call
  for rare eviction races, but normal generation reuses the resident engine.

## Android 4 GB memory policy

The runtime coordinator remains authoritative. Preloading diffusion may evict a
resident chat or Whisper runtime, and those workloads may later evict diffusion.
Only one heavyweight runtime remains resident on constrained Android devices.
Re-entering Image mode restores diffusion before the next prompt.

## UX and errors

- Settings and the image composer show model loading before the model becomes
  ready.
- Loading failures remain recoverable through the existing retry path.
- The selected model displays `Loading…` while preparing and `Ready` only after
  the backend engine is resident.
- Model download, cancellation, removal, and chat-generation progress keep their
  existing semantics.

## Testing

- Service tests prove explicit preparation loads once, evicts conflicting local
  work, and is reused by generation.
- Cubit tests prove initialize, install, and selection refresh preload the model.
- Cubit tests prove Send transitions directly to generation without a loading
  phase.
- Widget tests cover loading and ready labels in Settings and composer controls.
