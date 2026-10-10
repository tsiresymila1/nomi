# Local Dream evaluation

Date: 2026-10-11

## Decision

Nomi keeps `llamadart_stable_diffusion_flutter` as its image-generation
runtime. We will not embed or copy code from `xororz/local-dream`.

## Why

- Local Dream is licensed under CC BY-NC 4.0. Its non-commercial restriction
  is incompatible with a generally distributable application unless a
  separate commercial license is negotiated.
- Its accelerated path targets Qualcomm QNN/Snapdragon hardware and requires
  the Qualcomm QNN SDK. That path does not accelerate the Tensor SoC in the
  Pixel 6, which is Nomi's current Android validation device.
- It ships a native executable and a second stable-diffusion.cpp integration.
  Adopting it would duplicate Nomi's existing llamadart lifecycle, download,
  cancellation, progress, and memory-coordination layers.
- llamadart already exposes stable-diffusion.cpp through a Dart API, including
  memory checks, streaming progress, cancellation, samplers, and schedulers.

## What we reuse as product guidance

The repository is useful as an architectural reference only. Nomi keeps these
ideas in its own implementation:

- preload the selected image model before the user submits a prompt;
- keep generation in a foreground-visible workload with cancellable progress;
- select conservative defaults from device RAM and hardware capabilities;
- use model-specific sampler, scheduler, step, and guidance defaults;
- allow advanced models while clearly warning when they exceed the device
  tier.

No Local Dream source code, assets, binaries, or model packages are copied.

## Current Android catalog

| Profile | Intended tier | Runtime settings |
| --- | --- | --- |
| SDXS-512 Q8 | Recommended for 4 GB | 1 step, guidance 1 |
| Stable Diffusion 1.5 Q4 | 6 GB compatible | 20 steps, guidance 7 |
| DreamShaper 8 LCM Q4 | 6 GB experimental | 4 steps, LCM sampler |
| SDXL Turbo Q4 | 10 GB minimum / 12 GB recommended | 4 steps, Euler + SGM Uniform |

## Reconsideration conditions

Re-evaluate a separate NPU backend only if all of the following are true:

1. it has a commercial-compatible license;
2. it supports the target SoCs beyond Snapdragon-only QNN;
3. it can implement the existing `ImageGenerationBackend` contract without
   bypassing Nomi's runtime coordinator;
4. benchmarked end-to-end latency and memory are materially better than the
   llamadart backend on supported devices.

## References

- Local Dream: https://github.com/xororz/local-dream
- Local Dream license: https://github.com/xororz/local-dream/blob/master/LICENSE
- stable-diffusion.cpp: https://github.com/leejet/stable-diffusion.cpp
