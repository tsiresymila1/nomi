import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';

void main() {
  group('ImageModelCatalog', () {
    test('pins the Android-friendly SDXS profile', () {
      final profile = ImageModelCatalog.sdxs;

      expect(profile.id, 'sdxs-512-q8_0');
      expect(profile.fileName, 'sdxs-512-tinySDdistilled_Q8_0.gguf');
      expect(profile.sizeBytes, 682847200);
      expect(profile.steps, 1);
      expect(profile.guidanceScale, 1);
      expect(profile.deviceTier, ImageModelDeviceTier.recommended4Gb);
      expect(profile.isExternal, isFalse);
    });

    test('pins the experimental Stable Diffusion 1.5 Q4 profile', () {
      final profile = ImageModelCatalog.stableDiffusion15Q4;

      expect(profile.id, 'stable-diffusion-v1-5-q4_0');
      expect(
        profile.fileName,
        'stable-diffusion-v1-5-pruned-emaonly-Q4_0.gguf',
      );
      expect(profile.sizeBytes, 1566768416);
      expect(
        profile.sha256,
        'b2564c85cbda2ff00b820468ca6ce24ff9c728157d32ff00de874577175d5bba',
      );
      expect(profile.steps, 20);
      expect(profile.guidanceScale, 7);
      expect(profile.deviceTier, ImageModelDeviceTier.experimental);
    });

    test('resolves only built-in profile ids', () {
      expect(
        ImageModelCatalog.findBuiltIn(ImageModelCatalog.sdxs.id)?.name,
        ImageModelCatalog.sdxs.name,
      );
      expect(ImageModelCatalog.findBuiltIn('custom:missing'), isNull);
    });
  });

  test('external profile round-trips through JSON', () {
    final profile = ImageModelProfile.external(
      id: 'custom:test',
      name: 'My image model',
      filePath: '/storage/emulated/0/Models/image.gguf',
      sizeBytes: 42,
    );

    final restored = ImageModelProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.filePath, profile.filePath);
    expect(restored.sizeBytes, 42);
    expect(restored.sourceType, ImageModelSourceType.externalFile);
    expect(restored.deviceTier, ImageModelDeviceTier.custom);
    expect(restored.displaySize, '42 B');
  });
}
