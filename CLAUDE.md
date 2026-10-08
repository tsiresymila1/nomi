# CLAUDE.md — project rules for autopilot & Claude Code

Read `AGENTS.md` and `/Users/tsiresymila/.codex/RTK.md` before editing.

## Stack

- Flutter 3.41.9, Dart 3.11.5.
- State: `flutter_bloc` / `hydrated_bloc`; dependency injection: GetIt `sl`.
- Navigation: `go_router`; persistence: Drift; immutable models: Freezed.
- Local chat: Genkit + `genkit_llamadart` + `llamadart` (`.gguf` and `.litertlm`).
- Voice: Silero VAD + `whisper_ggml_plus` + `flutter_tts`.
- Workspace RAG: `mobile_rag_engine` with one collection per workspace.
- Run every shell command through `rtk`, including `rtk flutter analyze`,
  `rtk flutter test`, and `rtk dart run build_runner build --delete-conflicting-outputs`.

## Conventions

- Follow the existing feature-local data/presentation/service layout.
- Preserve current BLoC/GetIt patterns; do not introduce Riverpod or another state library.
- Keep widgets free of database, network, and native-runtime business logic.
- Put runtime orchestration in injectable `*Service` / `*Actions` classes.
- Use narrow provider-neutral interfaces around native packages so tests do not load native libraries.
- Add tests with every behavior change. Prefer focused unit/widget tests, then run the full suite.
- Preserve user-authored and unrelated dirty changes. Generated Drift/Freezed files change only when their sources require it.

## Boundaries

- `lib/core` owns shared platform, DI, database, routing, theme, and resource coordination.
- `lib/features/chat` owns conversation persistence, chat runtime orchestration, voice, attachments, and chat UI.
- `lib/features/downloads` owns model catalogs, downloads, install/remove state, and model readiness.
- `lib/features/workspace` owns document parsing, ingestion, vector search, and workspace policy.
- Image generation is a dedicated feature with an app-owned interface; it must not leak `llamadart` image types into chat widgets.
- All heavyweight local runtimes acquire a coordinator lease before load/generation on Android.
