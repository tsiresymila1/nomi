import 'package:gena/features/image_generation/data/models/image_generation_models.dart';

class DownloadedImageModelFile {
  const DownloadedImageModelFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

abstract interface class ImageModelDownloadClient {
  Future<DownloadedImageModelFile> download(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
  });

  Future<void> cancel(ImageModelProfile profile);
}

abstract interface class ImageModelStore {
  bool get isSupported;

  Future<InstalledImageModel?> resolve(ImageModelProfile profile);

  Future<InstalledImageModel> install(
    ImageModelProfile profile, {
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  });

  Future<void> cancelInstall(ImageModelProfile profile);

  Future<void> delete(ImageModelProfile profile);
}
