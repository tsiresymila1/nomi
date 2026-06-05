# AGENTS.md — Gena (Nomi) Flutter Project Guide

This file is the working contract for AI/code agents modifying this repository.

## 1) Project Mission

- App: `gena` (user-facing identity: **Nomi**).
- Platform: Flutter app with local-first AI chat + optional remote model support.
- Core goals:
  - Private local chat inference via `flutter_gemma`.
  - Model lifecycle (catalog, install/uninstall, remote sync).
  - Workspace-scoped chat + RAG docs + tool access controls.

## 2) Required Command Rule (Repo-Specific)

- Prefix shell commands with `rtk` (from `~/.codex/RTK.md`).
- Examples:
  - `rtk flutter analyze`
  - `rtk flutter test`
  - `rtk dart run build_runner build --delete-conflicting-outputs`
  - `rtk git status`

## 3) Current Toolchain Snapshot

- Flutter: `3.41.9`
- Dart: `3.11.5`
- DevTools: `2.54.2`

## 4) Repo Topology

- App code:
  - `lib/core` → database, DI, theme, router, shared utilities.
  - `lib/features/chat` → runtime/chat orchestration, tools, chat UI.
  - `lib/features/downloads` → model catalog, install/remove.
  - `lib/features/workspace` → workspace config, RAG ingestion/index/search.
  - `lib/features/home` → workspace/model entry state.
  - `lib/features/remote_servers` → remote server discovery, probe, sync.
  - `lib/features/setting` → persisted user/model display settings.
- Local package dependency:
  - `smart_background_tasks/` (path dependency in `pubspec.yaml`).
- Generated graph artifacts:
  - `graphify-out/` (informational; often noisy/dirty in git status).

## 5) Runtime Architecture (Must Understand Before Editing)

### 5.1 Composition Root

- Startup lives in `lib/main.dart`.
- Order is important:
  - `dotenv.load(".env")`
  - `setupServiceLocator()`
  - feature registrations (`registerDownloadsDependencies`, `registerChatDependencies`, etc.)
  - `HydratedBloc.storage` init
  - `FlutterGemma.initialize(...)`

### 5.2 Dependency Injection

- Primary DI: `GetIt` singleton `sl` in `lib/core/di/service_locator.dart`.
- Pattern:
  - `registerLazySingleton` + `isRegistered` guards.
  - Feature modules own their registration functions.
- Do not create duplicate registrations with conflicting lifecycles.

### 5.3 State Management

- Uses `flutter_bloc` / `hydrated_bloc` (not Riverpod for current active app flows).
- Persisted selections/settings include:
  - selected model
  - selected workspace
  - workspace drawer expansion map
  - chat model settings

### 5.4 Persistence

- Primary DB: Drift (`GenaDatabase`) in `lib/core/database/gena_database.dart`.
- Current schema version: `12`.
- Tables:
  - `workspaces`, `workspace_documents`, `chats`, `messages`, `models`.
- Migration strategy is incremental; never change existing migration semantics casually.

### 5.5 Chat Execution Path

- Main orchestrator: `ChatThreadActions.sendMessage(...)`.
- Generation engine:
  - local + remote paths unified via Genkit flow in `genkit_chat_service.dart`.
  - remote streaming/tool loop helpers in `remote_llm_service.dart`.
- Tool system:
  - definitions/execution in `lib/features/chat/data/tools/chat_tools.dart`
  - native bridge + approval flow in `native_tool_*` services/cubit.
- Workspace policy gates tool availability (native + RAG toggles).

### 5.6 Workspace RAG Path

- Import pipeline:
  - parse/copy: `WorkspaceDocumentParser`
  - queue: `WorkspaceRagIngestionQueue`
  - bootstrap: `WorkspaceRagIngestionBootstrap`
  - index/search: `WorkspaceRagVectorStore`
  - high-level ops: `WorkspaceRagActions`
- Ingestion state is persisted in `workspace_documents` and index rebuild is triggered from queue/actions.

## 6) Non-Negotiable Invariants

- Keep workspace/chat selection consistency:
  - `SelectedWorkspaceCubit` and `SelectedChatCubit` auto-sync behavior must stay intact.
- Preserve cancellation semantics:
  - chat generation uses serial/cancel tracking (`_generationSerial`, `_cancelGenerationSerial`).
- Preserve DB backward compatibility:
  - do not rewrite old migration blocks.
- Preserve native tool safety:
  - mutating native actions require explicit approval (`NativeToolActions` + `NativeToolExecutionCubit`).
- Preserve remote model identity mapping:
  - source format `remote-server://<serverId>/<encodedModelId>` is used for stale model cleanup.

## 7) Editing Rules for This Repo

- Prefer touching feature-local files before cross-cutting refactors.
- Keep DI registration colocated with feature service locator files.
- Reuse existing action/service abstractions:
  - avoid moving DB logic directly into widgets.
- Avoid introducing additional state libraries unless explicitly requested.
- Keep naming aligned with existing suffixes:
  - `*Cubit`, `*Service`, `*Actions`, `*Entity`.

## 8) Codegen and Generated Files

- Generated artifacts exist for Drift/Freezed/JSON:
  - `*.g.dart`, `*.freezed.dart`
- When changing annotated source models/tables, run:
  - `rtk dart run build_runner build --delete-conflicting-outputs`
- Current generated files include:
  - `lib/core/database/gena_database.g.dart`
  - `lib/features/downloads/data/models/model_info.freezed.dart`
  - `lib/features/downloads/data/models/model_info.g.dart`
  - `lib/features/chat/data/models/chat_entity.freezed.dart`
  - `lib/features/chat/data/models/chat_entity.g.dart`
  - `lib/features/chat/data/models/message_entity.freezed.dart`
  - `lib/features/chat/data/models/message_entity.g.dart`

## 9) Build/Test/Quality Workflow

- Install deps: `rtk flutter pub get`
- Analyze: `rtk flutter analyze`
- Tests: `rtk flutter test`
- APK build: `rtk flutter build apk --release`

Latest local check (at authoring time):
- `flutter analyze`: clean
- `flutter test`: pass (`test/widget_test.dart`)

## 10) Secrets and Environment

- `.env` is required and gitignored.
- Required runtime var:
  - `HUGGING_FACE_TOKEN`
- Token is used for:
  - `FlutterGemma.initialize(...)`
  - embedder installation (`WorkspaceEmbedderInstaller`)

Never hardcode secrets into source, tests, or logs.

## 11) CI/CD Notes

- Workflow: `.github/workflows/android-apk-release.yml`
- Triggers:
  - PR to `main`
  - manual dispatch
  - tag `v*`
- CI builds APK and publishes release on tag.

## 12) Known Working Patterns

- Router + page-level providers:
  - Global singleton cubits are injected with `BlocProvider.value`.
  - Route-specific cubits (ex: workspace config) are created in page builders.
- RAG enablement:
  - enabling RAG should ensure embedder is installed before save.
- Remote models:
  - synced into same `models` table with `provider = "remote"`.

## 13) Common Pitfalls to Avoid

- Don’t bypass service locator initialization order in `main.dart`.
- Don’t mix deprecated paths accidentally:
  - native tool services currently live under `lib/features/chat/data/tools/`.
- Don’t delete graph/report/generated files unless task explicitly asks.
- Don’t assume selected IDs are non-null/int-parseable; existing code guards this heavily.

## 14) Suggested Execution Strategy for Future Agents

1. Read `main.dart`, `core/di/service_locator.dart`, and target feature service locator first.
2. Trace flow through `*Actions`/`*Service` before editing UI.
3. Apply minimal patch set.
4. Run `rtk flutter analyze` and targeted tests.
5. If models/tables changed, run build_runner and re-check analysis.

