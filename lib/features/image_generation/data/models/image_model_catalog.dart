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
    deviceTier: ImageModelDeviceTier.experimental,
  );

  static const List<ImageModelProfile> builtIn = <ImageModelProfile>[
    sdxs,
    stableDiffusion15Q4,
  ];

  static ImageModelProfile? findBuiltIn(String id) {
    for (final profile in builtIn) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
