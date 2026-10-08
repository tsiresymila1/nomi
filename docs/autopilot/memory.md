# memory

> Short workflow lessons autopilot carries between runs.
> Read in Phase 1, appended in Phase 4. Keep entries one line: what happened → what to do.

- The repository uses BLoC/GetIt despite generic Flutter skill defaults → always preserve the project state-management architecture.
- Native features already have provider-neutral contracts → extend those seams instead of importing plugins into widgets.
- 2026-10-08 Android voice qualification: `flutter test` passed 512 tests and `flutter analyze lib test` reported zero issues → retain both as the release gate.
- 2026-10-08 ARM64 release: `flutter build apk --release --target-platform android-arm64` succeeded and produced a 129,898,149-byte APK → the pre-audio CI artifact at `72edaf8` was a 99,236,072-byte ZIP, so no raw-APK delta is claimed.
- 2026-10-08 Pixel 6 smoke test: release install succeeded on Android 17/API 37 and cold activity start completed in 3,016 ms → use this device for integration evidence, not as a 4 GB hardware claim because it exposes 7,787,844 kB RAM.
- 2026-10-08 idle memory: Nomi measured 175,350 kB total PSS and 294,612 kB total RSS after launch → keep the 4 GB target pending a real 4 GB device or constrained emulator run.
- 2026-10-08 Whisper Tiny provisioning: Settings showed Tiny recommended for 4 GB, Base required explicit confirmation, progress was visible at 0/47/96%, and Android exposed a `NO_CLEAR|FOREGROUND_SERVICE` notification with Pause/Cancel before reaching `Tiny is ready` → foreground download behavior is device-verified.
- 2026-10-08 hands-free smoke test: the release entered `Listening…`, exited back to chat, and measured 343,539 kB total PSS / 475,768 kB total RSS while listening → recognition quality, barge-in, and TTS still require a spoken manual session.
- 2026-10-08 audio attachment qualification: preparation/prompt/context/widget tests pass for WAV, MP3, M4A, AAC, FLAC, OGG, and OPUS, but ADB did not reliably complete the system file-picker selection → confirm one real audio attachment manually on hardware before store release.
