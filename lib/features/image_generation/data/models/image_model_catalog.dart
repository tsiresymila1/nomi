import 'package:gena/features/image_generation/data/models/image_generation_models.dart';

abstract final class ImageModelCatalog {
  static const String sdxsId = 'sdxs-512-q8_0';

  static const ImageModelProfile sdxs = ImageModelProfile.sdxs;

  static const ImageModelProfile stableDiffusion15Q4 = ImageModelProfile(
    id: 'stable-diffusion-v1-5-q4_0',
    name: 'Stable Diffusion 1.5 Q4',
    description:
        'Versatile local image model. Slower and memory-intensive on 4 GB phones.',
    url:
        'https://huggingface.co/second-state/stable-diffusion-v1-5-GGUF/resolve/031b5f5df991f511b3f5fa8fed6d99048ababb69/stable-diffusion-v1-5-pruned-emaonly-Q4_0.gguf?download=true',
    fileName: 'stable-diffusion-v1-5-pruned-emaonly-Q4_0.gguf',
    sizeBytes: 1566768416,
    sha256: 'b2564c85cbda2ff00b820468ca6ce24ff9c728157d32ff00de874577175d5bba',
    steps: 20,
    guidanceScale: 7,
    minimumRamBytes: 5 * 1024 * 1024 * 1024,
    recommendedRamBytes: 6 * 1024 * 1024 * 1024,
    deviceTier: ImageModelDeviceTier.compatible6Gb,
  );

  static const ImageModelProfile dreamShaper8LcmQ4 = ImageModelProfile(
    id: 'dreamshaper8-lcm-q4_0',
    name: 'DreamShaper 8 LCM Q4',
    description:
        'Fast LCM image model with four-step generation. Experimental on Android.',
    url:
        'https://huggingface.co/haven-ai-companion/dreamshaper8-lcm-gguf/resolve/56ac67e016b599c1eaf5be04e68980ff6bbdfa32/DreamShaper8_LCM_q4_0.gguf?download=true',
    fileName: 'DreamShaper8_LCM_q4_0.gguf',
    sizeBytes: 1625373856,
    sha256: 'a59b01541f145b1f799390922d99eb1182274e05f9e3037b7f627c5577b78866',
    steps: 4,
    guidanceScale: 1,
    minimumRamBytes: 5 * 1024 * 1024 * 1024,
    recommendedRamBytes: 6 * 1024 * 1024 * 1024,
    sampler: ImageModelSampler.lcm,
    deviceTier: ImageModelDeviceTier.experimental,
  );

  static const ImageModelProfile sdxlTurboQ4 = ImageModelProfile(
    id: 'sdxl-turbo-q4_0',
    name: 'SDXL Turbo Q4',
    description:
        'High-resolution distilled model for powerful devices. Not suitable for 4 GB phones.',
    url:
        'https://huggingface.co/gpustack/stable-diffusion-xl-1.0-turbo-GGUF/resolve/632cbcdd425c03a01667b9b5cdd7396b14f8cab8/stable-diffusion-xl-1.0-turbo-Q4_0.gguf?download=true',
    fileName: 'stable-diffusion-xl-1.0-turbo-Q4_0.gguf',
    sizeBytes: 3940010720,
    sha256: '5282eec23430ca46de87de984521fbf04e3cf78fa4152b05610089bc71d8a535',
    steps: 4,
    guidanceScale: 1,
    minimumRamBytes: 10 * 1024 * 1024 * 1024,
    recommendedRamBytes: 12 * 1024 * 1024 * 1024,
    sampler: ImageModelSampler.euler,
    scheduler: ImageModelScheduler.sgmUniform,
    deviceTier: ImageModelDeviceTier.experimental,
  );

  static const List<ImageModelProfile> builtIn = <ImageModelProfile>[
    sdxs,
    stableDiffusion15Q4,
    dreamShaper8LcmQ4,
    sdxlTurboQ4,
  ];

  static ImageModelProfile? findBuiltIn(String id) {
    for (final profile in builtIn) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
