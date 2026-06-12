# Llamadart Full Migration Design

## Goal

Fully remove `flutter_gemma` and `genkit_flutter_gemma` from Nomi. Use
`llamadart` and `genkit_llamadart` for local model inference, and use
`mobile_rag_engine` for native workspace RAG. Preserve remote OpenAI-compatible
models, chat streaming, tool approval, cancellation, workspace selection, and
the current background-download work.

The migration is developed on `codex/llamadart-migration`, created from
`feat/bloc` while carrying its uncommitted background-download changes.

## Scope

### Included

- Replace local generation, streaming, tool calls, model loading, and runtime
  disposal with `genkit_llamadart`.
- Replace FlutterGemma embeddings and vector storage with
  `mobile_rag_engine`.
- Replace every existing `.task` catalog source with a verified `.gguf` or
  `.litertlm` equivalent where one exists.
- Retire catalog entries only when no credible compatible replacement exists.
- Remove all `flutter_gemma` and `genkit_flutter_gemma` dependencies, imports,
  initialization, platform configuration, generated plugin registration, and
  obsolete Gemma-shaped services.
- Keep native local-model and RAG behavior on Android, iOS, and macOS.
- Keep web builds usable with remote OpenAI-compatible models only.
- Disable local-model and workspace-RAG controls on web with clear user-facing
  explanations.

### Excluded

- Replacing the existing remote OpenAI-compatible provider.
- Replacing Drift persistence for chats, messages, workspaces, documents, or
  model catalog entries.
- Reworking native tool approval or workspace permission policy.
- Adding cloud-hosted RAG for web.
- Preserving `.task` model compatibility.

## Package And Platform Baseline

- `llamadart: ^0.8.1`
- `genkit_llamadart: ^1.3.3`
- `mobile_rag_engine: ^0.18.6`
- Apple runtime companion packages for the model families retained in the
  catalog:
  - `llamadart_llama_cpp_flutter` for GGUF.
  - `llamadart_litert_lm_flutter` for LiteRT-LM.
- Remove `flutter_gemma`, its dependency override, and
  `genkit_flutter_gemma`.

`genkit_llamadart` requires Dart `^3.10.7`, which is compatible with the
project's Dart `3.11.5`. Apple builds using the companion packages require iOS
16.4 or newer and macOS 14.0 or newer. `mobile_rag_engine` supports Android,
iOS, and macOS; it does not provide the web RAG path used by this design.

## Architecture

### Genkit-Centered Local Runtime

`GenkitChatService` remains the single generation orchestration path for local
and remote models. The local branch registers a `LlamaDartPlugin` using the
selected model's downloaded file path, while the remote branch continues to
register the OpenAI plugin.

The local runtime boundary owns:

- Resolving and validating the selected model file.
- Mapping model settings to `ModelParams` and
  `LlamaDartGenerationConfig`.
- Creating and caching one prepared local model/runtime for the selected model.
- Disposing the previous runtime when model selection changes.
- Exposing token estimation through `genkit_llamadart` or a conservative
  fallback.
- Reporting unsupported platform or model-format errors before generation.

The generation path continues to build Genkit messages from Drift history,
register app-owned tools, stream draft text and thinking text, enforce
`maxTurns`, persist final messages, and honor the existing generation serial
and cancellation checks.

The migration removes FlutterGemma's duplicate direct-chat execution path.
`GemmaChatSession`, `ActiveGemmaModelRuntime`, FlutterGemma message replay,
FlutterGemma streaming parsing, and FlutterGemma-specific tool conversions are
deleted or replaced with provider-neutral helpers.

### Model Lifecycle

The app's existing background downloader owns local model files. A downloaded
compatible file is an installed local model; there is no second plugin-managed
installation registry.

Model lifecycle rules:

- Supported local extensions are `.gguf` and `.litertlm`.
- Network sources download to the stable application-support model directory.
- File sources are validated before selection or generation.
- `modelId` stores a stable app-owned identity derived from the downloaded file
  rather than a FlutterGemma installation spec.
- Installed-model listing is derived from valid local catalog file sources and
  existing downloaded files.
- Removing a local model disposes an active matching runtime, deletes its
  downloaded file when app-owned, and updates the catalog.
- Web rejects local-model selection and exposes remote models only.

### Catalog Migration

The default catalog is converted from FlutterGemma/LiteRT task sources to
llamadart-compatible sources.

For every existing entry:

1. Prefer an official or model-author-provided `.litertlm` replacement when
   the model family and target runtime are supported.
2. Otherwise use a reputable instruct/chat `.gguf` quantization that fits the
   entry's intended device tier.
3. Verify the source resolves to a single downloadable model file and document
   format, quantization, expected size, capabilities, and supported platforms.
4. Remove unsupported capability flags rather than claiming behavior not
   verified with the replacement.
5. Retire the entry only if no credible compatible replacement exists.

Existing user-created `.task` entries remain in the database but are marked
unsupported by validation and cannot be selected for local generation. No old
database migration block is rewritten.

### Workspace RAG

`WorkspaceRagVectorStore` remains the app-facing RAG boundary but delegates to
`mobile_rag_engine`.

- Initialize `MobileRag` once on supported native platforms.
- Bundle or otherwise provision a verified ONNX embedding model and matching
  tokenizer required by `mobile_rag_engine`.
- Map each workspace to a collection named from its stable workspace ID.
- Ingest each workspace document into its collection with metadata containing
  the app document ID, source type, source path, and name.
- Search only within the active workspace collection.
- Translate `mobile_rag_engine` search hits into the app's provider-neutral RAG
  result type consumed by `WorkspaceRagActions` and the chat tool.
- Rebuild only the requested workspace collection instead of clearing a global
  index.
- Preserve persisted ingestion state and current queue/bootstrap behavior.
- On web, RAG actions fail early with a typed unsupported-platform result and
  RAG controls are disabled.

The FlutterGemma embedder installer and embedder-selection checks are removed.
The workspace UI reports RAG engine initialization/indexing state instead.

### Platform Capability Boundary

Create a small app-owned capability helper used by model selection, downloads,
workspace configuration, and chat startup.

| Platform | Remote models | Local GGUF/LiteRT-LM | Workspace RAG |
|---|---:|---:|---:|
| Android | Yes | Yes | Yes |
| iOS | Yes | Yes | Yes |
| macOS | Yes | Yes | Yes |
| Web | Yes | No | No |
| Windows/Linux | Remote remains available; local support is not a release requirement for this migration |

On web:

- Hide or disable local install/select actions.
- Prevent local generation before runtime creation.
- Disable RAG enablement and ingestion controls.
- Explain that remote models remain available.

## Data Flow

### Local Chat

1. `ChatThreadActions.sendMessage` persists the user message and preserves the
   existing cancellation serial.
2. `generateAssistantResponseWithGenkit` resolves workspace policy, stored
   history, context window, and tools.
3. The local runtime controller validates the selected `.gguf` or `.litertlm`
   file and returns the cached or newly prepared `genkit_llamadart` runtime.
4. Genkit streams text, thinking, and tool turns through the existing UI cubits.
5. Tool execution continues through app-owned definitions and native approval.
6. Final thinking and assistant messages are persisted to Drift.

### Workspace RAG

1. Existing parser/queue code produces document content and ingestion work.
2. `WorkspaceRagVectorStore` selects the workspace collection and submits the
   document with app metadata to `mobile_rag_engine`.
3. The RAG tool searches the same workspace collection.
4. Search hits are translated to the existing tool-result shape and returned to
   the Genkit tool loop.

## Error Handling

- Missing, deleted, or unsupported model files produce actionable model
  lifecycle errors before generation starts.
- Runtime load failures dispose partially-created resources and leave the
  selected catalog entry intact.
- Model switching disposes the previous local runtime before creating another.
- Cancellation keeps the existing serial checks; runtime disposal is not used
  as the primary cancellation mechanism.
- RAG initialization and indexing errors are persisted through the existing
  workspace-document ingestion error state.
- Web unsupported operations return explicit platform errors rather than
  attempting native initialization.
- Remote generation remains available when local or RAG initialization fails.

## Testing

### Unit And Service Tests

- Platform capability behavior, especially web restrictions.
- Supported local model extension validation and installed-file discovery.
- Local runtime setting mapping and disposal on model switch.
- Genkit local model/reference/config resolution.
- Context-window fallback and token estimation.
- Catalog sources contain no `.task` defaults and all retained entries use
  compatible sources.
- `mobile_rag_engine` collection naming, metadata mapping, result translation,
  workspace isolation, rebuild behavior, and unsupported web behavior.
- Downloads cubit install/remove behavior without FlutterGemma's registry.

### Integration And Static Verification

- Local text streaming through `genkit_llamadart`.
- Tool-call loop through a compatible local model.
- Workspace ingestion and collection-scoped RAG search on a supported native
  target.
- Remote model generation still works.
- Web build exposes remote-only behavior.
- Repository search finds no production `flutter_gemma` or
  `genkit_flutter_gemma` references.
- Run targeted tests, `rtk flutter analyze`, `rtk flutter test`, native builds
  where available, and `rtk flutter build web`.

## Delivery Sequence

1. Establish platform capabilities and compatible dependencies.
2. Convert model lifecycle and catalog sources.
3. Replace local chat generation with `genkit_llamadart`.
4. Replace RAG with `mobile_rag_engine`.
5. Remove obsolete FlutterGemma code and platform integration.
6. Verify native local generation/RAG, remote generation, and remote-only web.

