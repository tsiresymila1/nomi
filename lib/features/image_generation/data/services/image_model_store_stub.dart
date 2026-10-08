import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';

ImageModelStore createPlatformImageModelStore() =>
    const UnsupportedImageModelStore();

class UnsupportedImageModelStore implements ImageModelStore {
  const UnsupportedImageModelStore();

  @override
  bool get isSupported => false;

  @override
  Future<void> cancelInstall(ImageModelProfile profile) async {}

  @override
  Future<void> delete(ImageModelProfile profile) async {}

  @override
  Future<InstalledImageModel> install(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) => throw UnsupportedError(
    'Local image models are unavailable on this platform.',
  );

  @override
  Future<InstalledImageModel?> resolve(ImageModelProfile profile) async => null;
}
