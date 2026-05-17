# Nomi

On-device AI assistant app built with Flutter.

Nomi is created by **Tsiresy Milà** and focused on local-first chat with downloadable models.

## Features

- On-device chat inference with `flutter_gemma`
- Multi-thread chat history with thread switch and create-new-thread flow
- Archive chat with confirmation, including delete of attached messages from database
- Auto-create and auto-select a new empty thread when archiving the active chat
- Model catalog (URL or file source) with add/install/remove flows
- Model install guard (prevents parallel installs to reduce memory pressure)
- Model metadata support:
  - `modelId` (runtime installed model id)
  - `modelType`
  - `supportImage`
  - `supportAudio`
  - `supportsFunctionCalls`
  - `isThinking`
- Model settings page:
  - system prompt
  - temperature, top-k, top-p
  - max tokens, token buffer, random seed
  - preferred backend
  - thinking override (use model default or force on/off)
- Chat input adapts to selected model capabilities:
  - image attach button when image is supported
  - audio button placeholder when audio is supported
  - send/stop generation toggle
- Image message support with files stored in app support directory
- Theme support (light/dark) with consistent app bar/status bar behavior
- Toast feedback using `Fluttertoast` (green success, red error, default info)
- Smooth UI animations with `flutter_animate` and loading states using `flutter_spinkit`
- Local persistence with Drift for chats, messages, and models

## Tech Stack

- Framework: `Flutter` / `Dart`
- State management: `flutter_riverpod`
- Routing: `go_router`
- On-device model runtime: `flutter_gemma`
- Local database: `drift` + `drift_flutter`
- Data models: `freezed`, `json_serializable`
- Storage & file access: `path_provider`, `file_picker`, `shared_preferences`
- UI libraries: `gpt_markdown`, `flutter_highlight`, `flutter_animate`, `flutter_spinkit`, `shimmer`, `hugeicons`
- Notifications/toasts: `fluttertoast`
- Tooling: `build_runner`, `flutter_lints`

## Project Structure

- `lib/features/chat`: chat page, input, history, provider logic
- `lib/features/downloads`: model repository, install/remove, add model sheet, download list
- `lib/features/setting`: app settings and model settings
- `lib/core`: router, theme, database, logging, prompt, toasts

## Database Tables

- `chats`
- `messages` (`kind`, `mediaPath`)
- `models` (`modelId`, capability flags, source info)

## Getting Started

1. Install Flutter (stable channel).
2. Fetch dependencies:
   - `flutter pub get`
3. Run app:
   - `flutter run`

## Build APK

- Local:
  - `flutter build apk --release`
- CI/CD:
  - GitHub Actions workflow: `.github/workflows/android-apk-release.yml`
  - Release artifact name: `nomi.apk`
  - Trigger:
    - manual (`workflow_dispatch`)
    - PR to `main`
    - tag push `v*` (publishes GitHub Release)

## Coming Future

- Add thinking message
- Add audio input (audio recording)
- Tools calling: internet search, mobile controller, etc.
- RAG integration and vector store
- Improve model download using custom foreground task and local notifications
- Optimization of model loading
