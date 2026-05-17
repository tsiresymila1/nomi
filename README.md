# Nomi

Local-first AI assistant built with Flutter.

Nomi is an on-device chat app created by **Tsiresy Milà**, focused on private inference, model flexibility, and a smooth mobile UX.

## Overview

- On-device LLM chat powered by `flutter_gemma`
- Local persistence for chats/messages/models
- Download/install/remove model workflow
- Capability-aware chat input (image/audio/function/thinking flags)
- Animated, theme-aware UI with lightweight architecture

## Features

### Chat

- Multi-thread chat history
- Archive chat with confirmation
- Delete archived chat messages from local database
- Auto-create and auto-select a new empty thread when active chat is archived
- Stop generation while streaming
- Image message support (stored in app support directory)

### Model Management

- Add model from URL or local file source
- Install/remove model with guard against concurrent install
- Persist model metadata:
  - `modelId`
  - `modelType`
  - `supportImage`
  - `supportAudio`
  - `supportsFunctionCalls`
  - `isThinking`
- Model settings controls:
  - system prompt
  - temperature, top-k, top-p
  - max tokens, token buffer, random seed
  - backend preference
  - thinking override

### UX

- Adaptive input actions based on selected model capabilities
- Toast feedback via `Fluttertoast` (success/error/info)
- Smooth transitions and UI animations (`flutter_animate`, `flutter_spinkit`)
- Light/dark theme with consistent status bar/app bar behavior

## Tech Stack

| Layer | Stack |
|---|---|
| App | Flutter, Dart |
| State Management | flutter_riverpod |
| Routing | go_router |
| On-device AI | flutter_gemma |
| Local Database | drift, drift_flutter |
| Modeling/Codegen | freezed, json_serializable, build_runner |
| Storage & File IO | path_provider, file_picker, shared_preferences |
| UI Libraries | gpt_markdown, flutter_highlight, flutter_animate, flutter_spinkit, shimmer, hugeicons |
| Feedback | fluttertoast |

## Project Structure

| Path | Responsibility |
|---|---|
| `lib/features/chat` | Chat page, history, input, providers |
| `lib/features/downloads` | Model catalog, add/install/remove flow |
| `lib/features/setting` | App and model settings |
| `lib/core` | Router, theme, database, logging, prompt, toast |

## Database

- `chats`
- `messages` (`kind`, `mediaPath`)
- `models` (`modelId`, model capabilities, source metadata)

## Getting Started

```bash
flutter pub get
flutter run
```

## Build APK

### Local

```bash
flutter build apk --release
```

### CI/CD

- Workflow: `.github/workflows/android-apk-release.yml`
- Artifact name: `nomi.apk`
- Triggers:
  - manual (`workflow_dispatch`)
  - PR to `main`
  - tag push `v*` (publishes GitHub release)

## Manual `.litertlm` Model URLs

Use direct `resolve/main/...litertlm?download=true` links (not model card page URLs).

### Recommended

- Gemma 4 E2B IT: [Download](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true)
- Qwen3 0.6B: [Download](https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm?download=true)

### More LiteRT Community Models

- Gemma 4 E4B IT: [Download](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm?download=true)
- Gemma 3 1B IT (int4): [Download](https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.litertlm?download=true)
- Qwen2.5 1.5B Instruct (q8): [Download](https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm?download=true)
- DeepSeek R1 Distill Qwen 1.5B (q8): [Download](https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm?download=true)
- Phi 4 Mini Instruct (q8): [Download](https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.litertlm?download=true)
- FastVLM 0.5B: [Download](https://huggingface.co/litert-community/FastVLM-0.5B/resolve/main/FastVLM-0.5B.litertlm?download=true)
- FunctionGemma Mobile Actions: [Download](https://huggingface.co/litert-community/functiongemma-270m-ft-mobile-actions/resolve/main/mobile_actions_q8_ekv1024.litertlm?download=true)
- Gemma 3 270M IT (q8): [Download](https://huggingface.co/litert-community/gemma-3-270m-it/resolve/main/gemma3-270m-it-q8.litertlm?download=true)
- Qwen3 4B: [Download](https://huggingface.co/litert-community/Qwen3-4B/resolve/main/qwen3_4b_channelwise_int8_float32kv.litertlm?download=true)
- Qwen3 8B: [Download](https://huggingface.co/litert-community/Qwen3-8B/resolve/main/qwen3_8b_channelwise_int8_float32kv.litertlm?download=true)

## Roadmap (Coming Future)

- Add thinking message
- Add Audio input (audio recording)
- Tools calling: Internet search, mobile controller and etc ..
- Rag integration, vectore store
- Improve download model by using custom foregroud task and local notification
- Optimissation of loading model

## Author

[Tsiresy Mila](https://tsiresymila.vercel.app)
