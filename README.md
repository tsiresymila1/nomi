# Nomi

**Local-first, on-device AI assistant built with Flutter** — by **Tsiresy Milà**.

Nomi runs large language models directly on your device for private chat, with
optional remote (OpenAI-compatible) models, on-device retrieval over your own
documents, voice in/out, vision, tools, and per-workspace memory. Designed so
that, on supported native platforms, your data never has to leave the device.

## Highlights

- **On-device LLM chat** via [`llamadart`](https://llamadart.leehack.com/) +
  `genkit_llamadart` — GGUF (llama.cpp) and LiteRT-LM (`.litertlm`) models.
- **Remote models** — any OpenAI-compatible endpoint (Ollama, LM Studio,
  LocalAI, …) for seamless local/remote switching.
- **Workspace RAG** — ingest documents and retrieve over them on-device with
  [`mobile_rag_engine`](https://pub.dev/packages/mobile_rag_engine) (hybrid
  BM25 + vector, MiniLM embeddings).
- **Tools / function calling** — web search, calculator, date, device info,
  workspace RAG search, native device actions (open URL/app, phone, SMS, email,
  contacts, flashlight), and **MCP** servers.
- **Voice input** — hold-to-record speech-to-text with on-device Whisper
  (`whisper_ggml_plus`).
- **Voice output** — read replies aloud (text-to-speech, `flutter_tts`).
- **Vision** — image understanding for multimodal models via the llamadart
  `mmproj` projector (e.g. SmolVLM2, Gemma 3 Nano).
- **Persistent memory** — the assistant remembers durable facts per workspace
  (`remember` / `forget` tools), auto-injected into context.
- **Model management** — download/install/remove with a persistent background
  downloader; gated Hugging Face models supported.
- **Workspaces** — per-workspace system instruction, model settings, and
  toggles for RAG, native tools, MCP, and memory.

## Platform capabilities

| Platform | Remote models | Local models | RAG | Voice (STT/TTS) | Vision | MCP |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Android | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| iOS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Web | ✅ | ❌ | ❌ | TTS only | ❌ | ✅ |
| Windows / Linux | ✅ (remote) | not a release target |

Capability policy lives in `lib/core/platform/app_capabilities.dart`; on
unsupported platforms the relevant controls are disabled with a clear message.

## Architecture

Feature-first modules under `lib/features`, wired with `get_it` and `flutter_bloc`:

| Path | Responsibility |
|---|---|
| `lib/features/chat` | Generation orchestration (Genkit), tools, voice in/out, chat UI |
| `lib/features/downloads` | Model catalog, background download, install/remove lifecycle |
| `lib/features/workspace` | Workspaces, RAG ingestion/search, persistent memory |
| `lib/features/mcp` | MCP server config + client + tool bridging |
| `lib/features/remote_servers` | OpenAI-compatible remote server config |
| `lib/features/setting` | App settings |
| `lib/core` | Router, DI, theme, Drift database, platform capabilities, logging |

Local and remote generation share one Genkit-centered path
(`genkit_chat_service`); local models load through a provider-neutral
`LocalModelRuntime`. RAG, STT, and MCP each sit behind a provider-neutral
boundary with a native implementation and a web/unsupported fallback selected by
a conditional factory.

## Tech stack

| Layer | Stack |
|---|---|
| App | Flutter, Dart (>= 3.11.5) |
| State / DI | flutter_bloc, hydrated_bloc, get_it |
| Routing | go_router |
| Local LLM | llamadart, genkit_llamadart, llamadart_llama_cpp_flutter, llamadart_litert_lm_flutter |
| Remote LLM | genkit, genkit_openai, openai_dart |
| RAG | mobile_rag_engine (MiniLM ONNX, first-run download) |
| Voice | whisper_ggml_plus (STT), record, flutter_tts (TTS) |
| Tools | MCP via mcp_dart; web search (ddgs), native device plugins |
| Database | drift, drift_flutter |
| Codegen | freezed, json_serializable, build_runner |
| UI | gpt_markdown, flutter_highlight, flutter_animate, flutter_spinkit, shimmer, hugeicons |

## Models

The default catalog (`lib/features/downloads/data/default_seed_models.dart`) ships
verified single-file `.litertlm` / `.gguf` sources (Gemma 4 / 3n, Qwen2.5 / 3,
DeepSeek R1 Distill, Phi-4 Mini, SmolLM2, SmolVLM2 vision, FunctionGemma, …).
You can also add any model by URL or local file (`.gguf` / `.litertlm`).
`tool/verify_model_catalog.dart` checks every catalog URL resolves (HTTP HEAD,
no body download). Gated Hugging Face models download with the configured token.

The RAG embedding model and tokenizer are **downloaded once on first RAG use**
(not bundled), keeping the app and repo small.

## Getting started

```bash
flutter pub get
flutter run
```

For local development that needs a Hugging Face token (gated models), provide a
`.env` (it is not bundled as a release asset).

## Quality

```bash
flutter analyze lib test
flutter test
```

CI (`.github/workflows/ci.yml`) runs analyze + the full test suite on every push
and PR to `main`. The APK release workflow lives in
`.github/workflows/android-apk-release.yml`.

## Build

```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS (signing required)
flutter build macos --release      # macOS
flutter build web                  # Web (remote-only)
```

Apple builds require iOS 16.4+ / macOS 14.0+ (llamadart Apple runtime).

## Author

[Tsiresy Milà](https://tsiresymila.vercel.app)
