# Nomi multimodal assistant backlog

> Owns: sequencing, exact implementation tasks, per-task mechanics, remaining gaps, future task intent.

## Milestones / sequencing

1. Chat reliability and typed runtime state.
2. ChatGPT-like streaming/loader/model-switch UX.
3. Multi-file turn attachments and workspace handoff.
4. Hands-free voice latency and recovery hardening.
5. Exclusive local runtime coordination for Android 4 GB.
6. Stable Diffusion explicit Image mode.
7. Confirmed remote fallback and end-to-end physical-device validation.

## Tasks (autopilot derives its queue from this)

- `p1-010` Establish committed product/design/plan docs and baseline analyzer/test gate.
- `p1-015` Serialize/deduplicate local runtime prepare/reset and prevent stale loads from becoming active.
- `p1-020` Atomically replace boolean model-switch state with typed phases, transactional selection/rollback/retry, deterministic warm-up ownership, and a compact loading surface that preserves the visible chat.
- `p1-040` Harden streaming Markdown placeholder, auto-scroll policy, cancellation, and error retry UX.
- `p2-010` Introduce typed multi-attachment draft state and file preparation service.
- `p2-020` Add document/image composer previews and persist turn-scoped attachment metadata.
- `p2-030` Route parsed documents to turn context and expose explicit workspace-index action.
- `p3-010` Add heavyweight runtime coordinator and integrate chat/STT leases.
- `p3-020` Measure and reduce hands-free voice latency; harden barge-in and recoverable failure states.
- `p4-010` Resolve official compatible `llamadart` image-generation dependency set or record an upstream blocker.
- `p4-020` Add SDXS installer/service with availability, progress, cancellation, checksum, and disposal.
- `p4-030` Add explicit Image composer mode and persist/display generated PNG messages.
- `p5-010` Add remote fallback proposal/confirmation and privacy disclosure.
- `p5-020` Run Android 4 GB physical/emulated performance scenarios and tune thresholds.

## Known gaps

- Current `ChatModelSwitchingCubit` exposes only a boolean and can race nested switch/warm-up operations.
- Current chat input accepts one image but not generic/multiple document attachments.
- Current voice stack exists and is sequential, but lacks an explicit shared heavyweight-runtime lease.
- Stable Diffusion requires `llamadart >=0.10.0`; the currently integrated Genkit bridge must be upgraded or proven compatible before code depends on image APIs.
- No confirmed remote fallback proposal exists.
- True 4 GB memory/performance verification requires a physical or constrained Android target and may finish as `needs-verification` in headless execution.
