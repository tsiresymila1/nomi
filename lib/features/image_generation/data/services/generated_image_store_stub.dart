import 'dart:typed_data';

import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';

GeneratedImageStore createPlatformGeneratedImageStore() =>
    const UnsupportedGeneratedImageStore();

class UnsupportedGeneratedImageStore implements GeneratedImageStore {
  const UnsupportedGeneratedImageStore();

  @override
  Future<String> savePng(Uint8List bytes, {required int seed}) =>
      throw UnsupportedError(
        'Generated images cannot be saved on this platform.',
      );
}
