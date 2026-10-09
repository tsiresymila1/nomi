# Selectable Image Models Design

**Date:** 2026-10-09  
**Status:** Approved for planning

## Goal

Make Settings the single source of truth for the Stable Diffusion model used by
image generation in every chat. Users can choose from a curated GGUF catalog or
register a compatible GGUF file already present on Android storage. Switching a
model must be explicit, safe for an Android device with 4 GB of RAM, and must
never duplicate an imported model file.

## Decisions

- Image model selection is global, persisted, and independent from the text LLM
  selection.
- The selected model in Settings is the model used by the chat image composer.
  The chat UI cannot maintain a conflicting selection.
- The initial curated catalog contains:
  - **SDXS-512 Q8**, the recommended fast profile for 4 GB Android devices.
  - **Stable Diffusion 1.5 Q4**, an experimental higher-quality profile with a
    prominent memory and speed warning.
- The catalog is data-driven. A curated entry is accepted only with a pinned
  immutable download URL, expected byte size, SHA-256 digest, generation
  defaults, license/source metadata, and a device recommendation.
- Users may register a single-file Stable Diffusion GGUF checkpoint from shared
  storage. Registration stores metadata and the original readable path; it does
  not copy the model into application storage.
- Multi-file diffusion families and arbitrary non-GGUF formats are outside this
  increment because the current `llamadart` adapter loads one model source.

## Architecture

### Model catalog and persisted registry

`ImageModelProfile` becomes a value object that describes both curated and
custom models. It includes a stable ID, display name, source type, path or URL,
file size, optional trusted digest, generation defaults, and a device support
level.

An `ImageModelCatalog` exposes the built-in profiles and resolves a profile by
ID. Custom profiles are stored by a small image-generation repository. The
repository persists only metadata and the original file path, never the model
bytes. The built-in catalog and custom registry are merged for presentation.

An `ImageModelSelectionCubit` persists the selected profile ID with
`HydratedCubit`, matching the existing settings architecture. It defaults to
SDXS-512 and falls back to SDXS-512 if a stored custom profile no longer exists.
It owns selection only; download and generation progress remain in
`ImageGenerationCubit`.

### Runtime boundary

`LocalImageGenerationService` no longer owns a constant SDXS profile. Each
operation resolves the current profile through the selection service. The
service serializes model changes with generation operations and records which
profile is loaded beside the resident engine.

When the selected profile changes, the service:

1. rejects the switch while confirmation has not been granted;
2. cancels an active install or generation when the user confirms;
3. disposes the resident diffusion engine and releases its runtime lease;
4. activates the new profile;
5. resolves its installation or external file availability;
6. publishes `ready`, `needsInstall`, or a recoverable file-access error.

Generation captures one profile at the start of the serialized operation. A
selection change therefore cannot mix one model's file with another model's
steps or guidance values. The assistant image message stores the captured model
name instead of the current hard-coded SDXS name.

## Settings Experience

Settings receives an **Image generation** card below the voice model card. It
shows all curated and custom profiles with:

- model name and GGUF quantization;
- download or external-file size;
- speed/quality description;
- `Recommended for 4 GB`, `Experimental`, or `Custom` badge;
- installed, missing, downloading, or unavailable state;
- the radio indicator for the globally selected model.

Selecting the current profile is a no-op. Selecting another profile opens a
confirmation dialog that names both models and explains that any active local
AI engine will be released. Experimental and custom models add a 4 GB memory
warning. Confirmation changes the global selection; it does not automatically
download a curated model. The selected profile's action then offers Download,
Cancel, Remove, or Locate again as appropriate.

The chat image status panel derives all labels, sizes, and readiness text from
the selected profile. It never displays `SDXS-512` unless SDXS is actually
selected.

## Custom GGUF Registration on Android

The custom-model action requests the Android storage access needed to obtain a
real filesystem path and registers that path directly. The app validates that:

- the path ends in `.gguf` case-insensitively;
- the file exists, is readable, and has a non-zero size;
- it is presented as a single-file checkpoint for the current llamadart image
  API; runtime compatibility is confirmed only when the engine loads it;
- the profile has safe default generation parameters before activation.

The app does not create a temporary or application-private copy. If Android
revokes access, the file moves, or the volume is disconnected, the profile
remains visible as unavailable and offers **Locate again** or **Remove from
list**. Registering a file does not claim runtime compatibility: the first load
may return a clear unsupported-model error without corrupting the current
selection or deleting the file.

Direct-path registration is Android-first. Other platforms may hide the action
until an equivalent durable-path implementation exists.

## Download and Storage Behavior

Curated models continue to use the existing foreground/background download
service, integrity verification, non-cancelable Android progress notification,
and application model directory. Each download is keyed by profile ID so
different profiles can coexist without progress collisions.

Removing a curated model deletes only that profile's managed file and checksum
marker. Removing a custom profile deletes only its Nomi metadata; it never
deletes the user's external GGUF file.

## Error Handling

- Invalid persisted profile IDs fall back to SDXS and are repaired on the next
  persisted state write.
- A missing curated model produces `needsInstall`; a missing custom file
  produces `unavailable` with Locate again.
- Integrity failures delete only the failed managed download.
- A failed switch keeps the newly selected profile visible with its actionable
  error; it does not silently generate with the previous model.
- Memory or native load failures explain that the model may exceed the device's
  capacity and offer returning to SDXS.
- Cancellation retains existing generation serial and runtime lease semantics.

## Testing

Unit and widget tests cover:

- catalog IDs, immutable metadata, and safe defaults;
- selection serialization, restoration, fallback, and confirmation behavior;
- direct custom-path registration without copy operations;
- per-profile install, resolve, cancel, and removal semantics;
- engine disposal and reload when changing profiles;
- generation using one captured profile and persisting its actual name;
- dynamic Settings and chat labels;
- missing external files, invalid GGUF paths, integrity errors, and low-memory
  failures;
- regression coverage for SDXS installation and generation.

Verification consists of targeted image-generation/settings tests, the full
Flutter test suite, static analysis, a release APK build, and a Pixel 6 smoke
test when the device is connected.

## Delivery Boundaries

Implementation is split into reviewable commits:

1. model catalog, custom registry, and persisted selection;
2. profile-aware runtime and model lifecycle;
3. Settings selection and custom GGUF registration UI;
4. chat integration, dynamic status UX, and end-to-end verification.

This increment does not add image-to-image, LoRA composition, multi-file FLUX
or SDXL bundles, per-chat image model overrides, or automatic remote catalog
discovery.

## Upstream References

- `stable-diffusion.cpp` supported formats and model families:
  https://github.com/leejet/stable-diffusion.cpp
- Distilled SDXS runtime parameters:
  https://github.com/leejet/stable-diffusion.cpp/blob/master/docs/distilled_sd.md
- Current app runtime: `llamadart 0.11.0` with
  `llamadart_stable_diffusion_flutter 0.0.2`.
