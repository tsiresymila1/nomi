# Llamadart Full Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fully remove FlutterGemma, run local models through `llamadart` and `genkit_llamadart`, replace workspace RAG with `mobile_rag_engine`, and keep web usable with remote models only.

**Architecture:** Keep Genkit as the unified local/remote generation path. Add app-owned platform, local-model-runtime, and RAG boundaries so native-only behavior is isolated and testable; preserve the current background downloader as the owner of local model files.

**Tech Stack:** Flutter, Dart, Bloc/GetIt, Drift, Genkit, `llamadart`, `genkit_llamadart`, `mobile_rag_engine`, `background_downloader`, `flutter_test`

---

## File Structure

### New Files

- `lib/core/platform/app_capabilities.dart` — app-owned capability policy.
- `lib/features/chat/data/services/local_model_runtime.dart` — provider-neutral local runtime contract and runtime state.
- `lib/features/chat/data/services/llamadart_local_model_runtime.dart` — native `genkit_llamadart` runtime owner.
- `lib/features/chat/data/services/unsupported_local_model_runtime.dart` — web/unsupported runtime implementation.
- `lib/features/chat/data/services/local_model_runtime_factory.dart` — conditional export selecting the runtime implementation.
- `lib/features/downloads/data/local_model_files.dart` — compatible-format validation, stable IDs, and installed-file discovery.
- `lib/features/workspace/data/models/workspace_rag_result.dart` — app-owned RAG result.
- `lib/features/workspace/data/services/workspace_rag_backend.dart` — RAG backend contract.
- `lib/features/workspace/data/services/mobile_workspace_rag_backend.dart` — native `mobile_rag_engine` adapter.
- `lib/features/workspace/data/services/unsupported_workspace_rag_backend.dart` — web/unsupported adapter.
- `lib/features/workspace/data/services/workspace_rag_backend_factory.dart` — conditional export selecting the RAG backend.
- `assets/rag/model.onnx` and `assets/rag/tokenizer.json` — verified matching embedding model artifacts.
- Focused tests under `test/core/platform`, `test/features/downloads`, `test/features/chat`, and `test/features/workspace`.

### Removed Files

- `lib/features/chat/data/models/gemma_chat_session.dart`
- `lib/features/chat/data/services/chat_session_history_service.dart`
- `lib/features/chat/data/services/chat_session_runtime_service.dart`
- `lib/features/chat/data/services/chat_session_service.dart`
- `lib/features/chat/data/services/chat_thread_execution_service.dart`
- `lib/features/chat/data/services/chat_thread_streaming_service.dart`
- `lib/features/workspace/data/services/workspace_embedder_installer.dart`
- `lib/features/downloads/data/default_embedder_models.dart`

### Primary Modified Files

- `pubspec.yaml`, `lib/main.dart`, Apple/Android platform configuration.
- `lib/features/chat/data/services/genkit_chat_service.dart`
- `lib/features/chat/data/services/chat_thread_actions_service.dart`
- `lib/features/chat/data/services/chat_thread_context_service.dart`
- `lib/features/chat/data/services/chat_title_service.dart`
- `lib/features/chat/data/chat_service_locator.dart`
- `lib/features/downloads/data/default_seed_models.dart`
- `lib/features/downloads/data/model_repository.dart`
- `lib/features/downloads/presentation/cubit/downloads_cubit.dart`
- `lib/features/workspace/data/services/workspace_rag_vector_store.dart`
- `lib/core/database/gena_database.dart` and generated Drift code for persisted RAG source IDs.
- Workspace/home presentation files that currently expose FlutterGemma embedder state.

---

### Task 1: Stabilize The Carried Background Downloader Work

**Files:**
- Modify: existing dirty download/platform files on `codex/llamadart-migration`
- Test: `test/features/downloads/data/services/model_download_task_test.dart`

- [ ] Run `rtk git status --short` and confirm the carried download changes are present.
- [ ] Run `rtk flutter test test/features/downloads/data/services/model_download_task_test.dart`.
- [ ] Run `rtk flutter analyze`.
- [ ] Fix only failures caused by the carried background-download migration.
- [ ] Run `rtk git diff --check`.
- [ ] Commit the stabilized prerequisite:

```bash
rtk git add android/app/src/main/AndroidManifest.xml ios/Podfile ios/Runner.xcodeproj/project.pbxproj ios/Runner/AppDelegate.swift macos/Flutter/GeneratedPluginRegistrant.swift pubspec.yaml pubspec.lock lib/features/downloads/data/services/model_background_download_service.dart lib/features/downloads/data/services/model_download_task.dart lib/features/downloads/presentation/cubit/downloads_cubit.dart test/features/downloads/data/services/model_download_task_test.dart
rtk git commit -m "refactor: migrate model downloads to background downloader"
```

### Task 2: Add Platform Capability Policy

**Files:**
- Create: `lib/core/platform/app_capabilities.dart`
- Create: `test/core/platform/app_capabilities_test.dart`
- Modify: `lib/features/downloads/presentation/cubit/downloads_cubit.dart`
- Modify: `lib/features/chat/data/services/chat_page_actions_service.dart`
- Modify: `lib/features/workspace/presentation/widgets/workspace_config_form.dart`

- [ ] Write failing tests for the explicit policy:

```dart
test('web supports remote models but not local models or RAG', () {
  const capabilities = AppCapabilities.forPlatform(AppPlatform.web);
  expect(capabilities.supportsRemoteModels, isTrue);
  expect(capabilities.supportsLocalModels, isFalse);
  expect(capabilities.supportsWorkspaceRag, isFalse);
});

test('supported native mobile platforms expose local models and RAG', () {
  for (final platform in [AppPlatform.android, AppPlatform.ios, AppPlatform.macos]) {
    final capabilities = AppCapabilities.forPlatform(platform);
    expect(capabilities.supportsLocalModels, isTrue);
    expect(capabilities.supportsWorkspaceRag, isTrue);
  }
});
```

- [ ] Run `rtk flutter test test/core/platform/app_capabilities_test.dart` and verify it fails because the capability types do not exist.
- [ ] Implement `AppPlatform`, `AppCapabilities.current`, and `AppCapabilities.forPlatform`.
- [ ] Guard local install/select actions and RAG enablement with the capability policy.
- [ ] On web, disable controls and show: `Local models and workspace RAG are unavailable on web. Remote models remain available.`
- [ ] Run the targeted test and commit:

```bash
rtk git add lib/core/platform/app_capabilities.dart test/core/platform/app_capabilities_test.dart lib/features/downloads/presentation/cubit/downloads_cubit.dart lib/features/chat/data/services/chat_page_actions_service.dart lib/features/workspace/presentation/widgets/workspace_config_form.dart
rtk git commit -m "feat: define local AI platform capabilities"
```

### Task 3: Replace Plugin-Managed Installation With File-Based Model Lifecycle

**Files:**
- Create: `lib/features/downloads/data/local_model_files.dart`
- Create: `test/features/downloads/data/local_model_files_test.dart`
- Modify: `lib/features/downloads/data/model_repository.dart`
- Modify: `lib/features/downloads/data/model_readiness.dart`
- Modify: `lib/features/downloads/presentation/cubit/downloads_cubit.dart`
- Modify: `lib/features/downloads/presentation/add_model_page.dart`
- Modify: `lib/features/downloads/presentation/widgets/model_basic_info_section.dart`

- [ ] Write failing tests proving:
  - `.gguf` and `.litertlm` are supported.
  - `.task` and unknown extensions are rejected.
  - a stable installed ID is derived from the normalized local path.
  - only existing compatible local files are reported as installed.

```dart
test('supports only llamadart model formats', () {
  expect(isSupportedLocalModelSource('/models/chat.gguf'), isTrue);
  expect(isSupportedLocalModelSource('/models/chat.litertlm'), isTrue);
  expect(isSupportedLocalModelSource('/models/chat.task'), isFalse);
});
```

- [ ] Run `rtk flutter test test/features/downloads/data/local_model_files_test.dart` and verify RED.
- [ ] Implement pure format validation and stable identity helpers.
- [ ] Change `ModelInstallerService.listInstalledModels()` to inspect catalog file sources instead of FlutterGemma's registry.
- [ ] Change `DownloadsCubit.installModel` so a completed compatible download is immediately installed; write the stable ID to `modelId` and do not call a second plugin installer.
- [ ] Change removal to delete app-owned files and update the catalog without calling `FlutterGemma.uninstallModel`; Task 8 reconnects active runtime reset/cancellation.
- [ ] Validate add/edit model sources and explain unsupported `.task` files.
- [ ] Run targeted tests and commit:

```bash
rtk git add lib/features/downloads/data/local_model_files.dart test/features/downloads/data/local_model_files_test.dart lib/features/downloads/data/model_repository.dart lib/features/downloads/data/model_readiness.dart lib/features/downloads/presentation
rtk git commit -m "refactor: manage local models as llamadart files"
```

### Task 4: Convert And Verify The Default Model Catalog

**Files:**
- Modify: `lib/features/downloads/data/default_seed_models.dart`
- Modify: `lib/features/downloads/data/default_static_models.dart`
- Create: `test/features/downloads/data/default_seed_models_test.dart`
- Create: `tool/verify_model_catalog.dart`

- [ ] Write failing catalog tests:

```dart
test('all default local model sources are llamadart compatible', () {
  for (final model in kDefaultSeedModels) {
    expect(model.sourceUrl.endsWith('.gguf') || model.sourceUrl.endsWith('.litertlm'), isTrue);
    expect(model.sourceUrl.endsWith('.task'), isFalse);
  }
});
```

- [ ] Run the targeted test and verify existing `.task` entries fail.
- [ ] Audit every current catalog entry using the following deterministic rules:
  - Use the existing `desktopUrl` when it is a `.litertlm`.
  - Otherwise select a single-file instruct/chat GGUF from the model author or a reputable GGUF publisher.
  - Prefer `Q4_K_M` for general mobile CPU entries unless the model's official compatible bundle is available.
  - Preserve capability flags only after checking the selected model card and a real smoke test.
  - Retire an entry when no verified single-file `.gguf`/`.litertlm` replacement exists.
- [ ] Create `tool/verify_model_catalog.dart` to iterate `kDefaultSeedModels`, reject non-`.gguf`/`.litertlm` sources, issue an `HttpClient` request with redirects enabled for every concrete source URL, and exit non-zero unless every source resolves successfully.
- [ ] Run:

```bash
rtk dart run tool/verify_model_catalog.dart
```

  Expected: one success line per retained model and process exit code `0`.
- [ ] Update catalog notes from FlutterGemma terminology to llamadart format, quantization, size, and capability information.
- [ ] Run the catalog test and commit:

```bash
rtk git add lib/features/downloads/data/default_seed_models.dart lib/features/downloads/data/default_static_models.dart test/features/downloads/data/default_seed_models_test.dart tool/verify_model_catalog.dart
rtk git commit -m "feat: migrate default catalog to llamadart models"
```

### Task 5: Add And Configure Llamadart Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `ios/Podfile`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`

- [ ] Add `llamadart`, `genkit_llamadart`, `llamadart_llama_cpp_flutter`, and `llamadart_litert_lm_flutter`.
- [ ] Keep FlutterGemma dependencies temporarily so intermediate commits continue to analyze while the old runtime is replaced.
- [ ] Raise Apple deployment targets to iOS 16.4 and macOS 14.0.
- [ ] Run `rtk flutter pub get`.
- [ ] Run `rtk flutter analyze`; expected result: clean.
- [ ] Commit the dependency/platform baseline:

```bash
rtk git add pubspec.yaml pubspec.lock ios/Podfile ios/Runner.xcodeproj/project.pbxproj macos/Runner.xcodeproj/project.pbxproj
rtk git commit -m "build: add llamadart runtime dependencies"
```

### Task 6: Implement The Local Model Runtime Boundary

**Files:**
- Create: `lib/features/chat/data/services/local_model_runtime.dart`
- Create: `lib/features/chat/data/services/llamadart_local_model_runtime.dart`
- Create: `lib/features/chat/data/services/unsupported_local_model_runtime.dart`
- Create: `lib/features/chat/data/services/local_model_runtime_factory.dart`
- Create: `test/features/chat/data/services/local_model_runtime_test.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`

- [ ] Write failing tests using a fake runtime driver for:
  - cache reuse for the same selected model and settings.
  - disposal before switching model files.
  - `cancelActiveGeneration()` forwarding.
  - token counting falling back to `fallbackTokenEstimate`.
  - unsupported runtime rejecting local preparation on web.
- [ ] Define the app-owned contract:

```dart
abstract interface class LocalModelRuntime {
  Future<PreparedLocalModel> prepare(ModelInfo model);
  Future<int> countTokens(String text);
  void cancelActiveGeneration();
  Future<void> reset();
}

class PreparedLocalModel {
  const PreparedLocalModel({
    required this.ai,
    required this.modelRef,
    required this.modelId,
  });
  final Genkit ai;
  final ModelRef<dynamic> modelRef;
  final String modelId;
}
```

- [ ] Implement the native runtime with `LlamaModelDefinition(modelPath: ...)`, `ModelParams(contextSize: model.maxTokens)`, one cached prepared model, `LlamaPreparedModel.cancelActiveGeneration()`, and deterministic disposal.
- [ ] Implement the unsupported runtime without importing native-only APIs.
- [ ] Register `LocalModelRuntime` in GetIt through the conditional factory.
- [ ] Run the targeted runtime tests and commit:

```bash
rtk git add lib/features/chat/data/services/local_model_runtime.dart lib/features/chat/data/services/llamadart_local_model_runtime.dart lib/features/chat/data/services/unsupported_local_model_runtime.dart lib/features/chat/data/services/local_model_runtime_factory.dart lib/features/chat/data/chat_service_locator.dart test/features/chat/data/services/local_model_runtime_test.dart
rtk git commit -m "feat: add llamadart local model runtime"
```

### Task 7: Move Local Generation Fully Onto Genkit Llamadart

**Files:**
- Modify: `lib/features/chat/data/services/genkit_chat_service.dart`
- Modify: `lib/features/chat/data/services/chat_runtime_dependencies.dart`
- Modify: `lib/features/chat/data/services/chat_thread_context_service.dart`
- Modify: `lib/features/chat/data/tools/chat_tools.dart`
- Create: `test/features/chat/data/services/genkit_chat_service_test.dart`

- [ ] Write failing tests for local model resolution/config mapping:
  - local models use the prepared llamadart `ModelRef`.
  - `temperature`, `topK`, `topP`, output token reserve, random seed, and thinking map to `LlamaDartGenerationConfig`.
  - remote models still use the existing OpenAI plugin path.
  - tools remain app-owned Genkit tools.
- [ ] Replace `GenkitFlutterGemmaPlugin`, `flutterGemma.model`, and `FlutterGemmaModelOptions` with the prepared local runtime and `LlamaDartGenerationConfig`.
- [ ] Make context-window planning provider-neutral by accepting a `Future<int> Function(String)` token counter and representing replay history as stored Drift messages/Genkit messages.
- [ ] Remove FlutterGemma tool conversion helpers while preserving unified tool definitions and native approval.
- [ ] Preserve streaming drafts, thinking extraction, tool-result fallback, cancellation checks, and final persistence.
- [ ] Run the targeted tests and commit:

```bash
rtk git add lib/features/chat/data/services/genkit_chat_service.dart lib/features/chat/data/services/chat_runtime_dependencies.dart lib/features/chat/data/services/chat_thread_context_service.dart lib/features/chat/data/tools/chat_tools.dart test/features/chat/data/services/genkit_chat_service_test.dart
rtk git commit -m "feat: generate local chat with genkit llamadart"
```

### Task 8: Remove Gemma Session Execution And Reconnect Chat Actions

**Files:**
- Modify: `lib/features/chat/data/services/chat_thread_actions_service.dart`
- Modify: `lib/features/chat/data/services/chat_page_actions_service.dart`
- Modify: `lib/features/chat/data/services/chat_title_service.dart`
- Modify: `lib/features/chat/data/chat_service_locator.dart`
- Delete: `lib/features/chat/data/models/gemma_chat_session.dart`
- Delete: `lib/features/chat/data/services/chat_session_history_service.dart`
- Delete: `lib/features/chat/data/services/chat_session_runtime_service.dart`
- Delete: `lib/features/chat/data/services/chat_session_service.dart`
- Delete: `lib/features/chat/data/services/chat_thread_execution_service.dart`
- Delete: `lib/features/chat/data/services/chat_thread_streaming_service.dart`
- Create: `test/features/chat/data/services/chat_thread_context_service_test.dart`

- [ ] Write failing tests for stored-message compaction, output reserve, image token fallback, and local runtime cancellation.
- [ ] Replace `ChatSessionController` dependencies with `LocalModelRuntime`.
- [ ] Change local readiness/warmup to `LocalModelRuntime.prepare`.
- [ ] Change stop-generation to preserve `_generationSerial`/`_cancelGenerationSerial` and call `LocalModelRuntime.cancelActiveGeneration`.
- [ ] Generate local titles with a short Genkit request against the prepared local model instead of a FlutterGemma session.
- [ ] Delete obsolete Gemma session/runtime/streaming files and imports.
- [ ] Run targeted chat tests and commit:

```bash
rtk git add lib/features/chat test/features/chat
rtk git commit -m "refactor: remove flutter gemma chat sessions"
```

### Task 9: Add The Mobile RAG Backend Boundary

**Files:**
- Create: `lib/features/workspace/data/models/workspace_rag_result.dart`
- Create: `lib/features/workspace/data/services/workspace_rag_backend.dart`
- Create: `lib/features/workspace/data/services/mobile_workspace_rag_backend.dart`
- Create: `lib/features/workspace/data/services/unsupported_workspace_rag_backend.dart`
- Create: `lib/features/workspace/data/services/workspace_rag_backend_factory.dart`
- Create: `test/features/workspace/data/services/workspace_rag_backend_test.dart`
- Modify: `pubspec.yaml`
- Add: `assets/rag/model.onnx`
- Add: `assets/rag/tokenizer.json`

- [ ] Add `mobile_rag_engine: ^0.18.6` and declare the matching RAG assets.
- [ ] Use the package-recommended `all-MiniLM-L6-v2` INT8 ONNX model and matching tokenizer; record their source URLs and SHA-256 values in a short comment beside the asset declarations or a repository doc.
- [ ] Write failing contract tests with a fake backend for:
  - collection name `workspace_<id>`.
  - document metadata mapping.
  - provider-neutral result translation.
  - unsupported web initialization/search.
- [ ] Define the backend contract and app-owned ingest result:

```dart
class WorkspaceRagDocument {
  const WorkspaceRagDocument({
    required this.documentId,
    required this.name,
    required this.sourceType,
    required this.sourcePath,
    required this.content,
  });
  final int documentId;
  final String name;
  final String sourceType;
  final String sourcePath;
  final String content;
}

class WorkspaceRagIngestResult {
  const WorkspaceRagIngestResult({
    required this.sourceId,
    required this.chunkCount,
  });
  final int sourceId;
  final int chunkCount;
}

abstract interface class WorkspaceRagBackend {
  Future<void> ensureReady();
  Future<WorkspaceRagIngestResult> addDocument(
    String workspaceId,
    WorkspaceRagDocument document,
  );
  Future<void> removeDocument(String workspaceId, int sourceId);
  Future<void> rebuildWorkspace(String workspaceId);
  Future<List<WorkspaceRagResult>> search(
    String workspaceId,
    String query, {
    required int topK,
    required double threshold,
  });
}
```

- [ ] Implement native initialization with `MobileRag.initialize`, `deferIndexWarmup: true`, and workspace collections through `MobileRag.instance.inCollection('workspace_$workspaceId')`.
- [ ] Map `SourceAddResult.sourceId` and `SourceAddResult.chunkCount` into `WorkspaceRagIngestResult`; map removal to collection-scoped `removeSource`, and rebuild to collection-scoped `rebuildIndex(force: true)`.
- [ ] Translate hybrid hits into `WorkspaceRagResult`, filter below the app threshold in the adapter, and preserve source/document metadata for the chat RAG tool.
- [ ] Implement unsupported behavior without importing `mobile_rag_engine`.
- [ ] Run targeted tests and commit:

```bash
rtk git add pubspec.yaml pubspec.lock assets/rag lib/features/workspace/data/models/workspace_rag_result.dart lib/features/workspace/data/services/workspace_rag_backend.dart lib/features/workspace/data/services/mobile_workspace_rag_backend.dart lib/features/workspace/data/services/unsupported_workspace_rag_backend.dart lib/features/workspace/data/services/workspace_rag_backend_factory.dart test/features/workspace/data/services/workspace_rag_backend_test.dart
rtk git commit -m "feat: add mobile rag engine backend"
```

### Task 10: Reconnect Workspace RAG And Remove Embedder Management

**Files:**
- Modify: `lib/core/database/gena_database.dart`
- Regenerate: `lib/core/database/gena_database.g.dart`
- Modify: `lib/features/workspace/data/services/workspace_rag_vector_store.dart`
- Modify: `lib/features/workspace/data/services/workspace_rag_actions_service.dart`
- Modify: `lib/features/workspace/data/services/workspace_rag_ingestion_queue.dart`
- Modify: `lib/features/workspace/data/services/workspace_rag_ingestion_bootstrap.dart`
- Modify: `lib/features/workspace/data/services/workspace_rag_core_service.dart`
- Modify: `lib/features/workspace/presentation/workspace_presentation_service_locator.dart`
- Modify: `lib/features/home/presentation/cubit/home_service_locator.dart`
- Modify: `lib/features/workspace/presentation/cubit/workspace_embedder_install_cubit.dart`
- Modify: `lib/features/workspace/presentation/widgets/workspace_embedder_status_card.dart`
- Modify: `lib/features/workspace/presentation/widgets/workspace_config_form.dart`
- Modify: `lib/features/home/presentation/cubit/home_cubit.dart`
- Delete: `lib/features/workspace/data/services/workspace_embedder_installer.dart`
- Delete: `lib/features/downloads/data/default_embedder_models.dart`
- Create: `test/features/workspace/data/services/workspace_rag_vector_store_test.dart`

- [ ] Add nullable `ragSourceId` to `WorkspaceDocuments`, increment schema version from 12 to 13, and add only a new `if (from < 13)` migration block. Never rewrite existing migration blocks.
- [ ] Run `rtk dart run build_runner build --delete-conflicting-outputs`.
- [ ] Write failing tests proving add/remove/rebuild/search are workspace-scoped and one workspace rebuild does not clear another workspace.
- [ ] Change `WorkspaceRagVectorStore` to delegate to `WorkspaceRagBackend` and return `WorkspaceRagResult`.
- [ ] Change ingestion to submit the parsed document content once, persist returned `ragSourceId` and engine `chunkCount`, and remove an older source ID before replacing a document.
- [ ] Change document deletion to remove its persisted source ID from its workspace collection before deleting the Drift row.
- [ ] Rebuild each affected workspace collection independently; do not clear a global index or duplicate already-persisted sources.
- [ ] On startup, enqueue ready documents with `ragSourceId == null` so existing FlutterGemma-era documents migrate into `mobile_rag_engine`.
- [ ] Preserve ingestion queue statuses and error persistence.
- [ ] Replace “embedder install” state/messages with RAG engine readiness/indexing state.
- [ ] Remove FlutterGemma embedder checks from home and workspace flows.
- [ ] Ensure web RAG actions return `unsupported_platform` and the UI disables RAG controls.
- [ ] Run targeted workspace tests and commit:

```bash
rtk git add lib/features/workspace lib/features/home/presentation/cubit/home_cubit.dart lib/features/downloads/data/default_embedder_models.dart test/features/workspace
rtk git commit -m "refactor: migrate workspace rag to mobile rag engine"
```

### Task 11: Remove Remaining FlutterGemma References And Generated Integration

**Files:**
- Modify/Delete: every remaining file reported by the repository search
- Regenerate: platform plugin registrants and lockfiles through Flutter tooling

- [ ] Remove FlutterGemma initialization from `lib/main.dart`, remove FlutterGemma-specific Android dependency alignment/platform configuration, and remove `flutter_gemma`, `genkit_flutter_gemma`, and the dependency override from `pubspec.yaml`.
- [ ] Run:

```bash
rtk rg -n "flutter_gemma|FlutterGemma|genkit_flutter_gemma|gemma\\." lib test pubspec.yaml android ios macos linux windows web
```

- [ ] Remove every production reference. Rename misleading Gemma-specific app-owned identifiers to local-model/provider-neutral names.
- [ ] Run `rtk flutter clean`.
- [ ] Run `rtk flutter pub get` to regenerate plugin registration and lockfiles.
- [ ] Re-run the repository search; expected output is empty except historical design/plan documentation.
- [ ] Run `rtk dart format lib test`.
- [ ] Stage only migration-related files shown by `rtk git status --short`; do not stage unrelated graph/report artifacts.
- [ ] Commit cleanup:

```bash
rtk git commit -m "refactor: remove flutter gemma integration"
```

### Task 12: Verify Native, Remote, RAG, And Web Behavior

**Files:**
- Verify: entire project
- Modify: only files required to fix verification failures

- [ ] Run focused tests:

```bash
rtk flutter test test/core/platform/app_capabilities_test.dart
rtk flutter test test/features/downloads
rtk flutter test test/features/chat
rtk flutter test test/features/workspace
```

- [ ] Run full static and unit verification:

```bash
rtk flutter analyze
rtk flutter test
rtk git diff --check
```

- [ ] Run builds:

```bash
rtk flutter build apk --debug
rtk flutter build ios --debug --no-codesign
rtk flutter build macos --debug
rtk flutter build web
```

- [ ] On at least one supported native target, manually verify:
  - download and select a compatible local model.
  - stream a local text response.
  - cancel generation and preserve the partial draft.
  - execute a safe tool call and confirm mutating native tools still require approval.
  - import a workspace document and retrieve it through the RAG tool.
  - switch models and confirm the previous local runtime is disposed.
  - use a remote model after local/RAG activity.
- [ ] In web, verify local install/select and RAG controls are disabled while remote chat remains available.
- [ ] Run the final forbidden-reference search and inspect status:

```bash
rtk rg -n "flutter_gemma|FlutterGemma|genkit_flutter_gemma" lib test pubspec.yaml android ios macos linux windows web
rtk git status --short
```

- [ ] Stage only verification fixes made for this migration and commit them, if any:

```bash
rtk git commit -m "test: verify llamadart migration"
```
