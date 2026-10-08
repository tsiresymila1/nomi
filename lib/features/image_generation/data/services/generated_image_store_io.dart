import 'dart:io';
import 'dart:typed_data';

import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';
import 'package:path_provider/path_provider.dart';

GeneratedImageStore createPlatformGeneratedImageStore() =>
    const IoGeneratedImageStore();

class IoGeneratedImageStore implements GeneratedImageStore {
  const IoGeneratedImageStore();

  @override
  Future<String> savePng(Uint8List bytes, {required int seed}) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/generated_images');
    await directory.create(recursive: true);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${directory.path}/nomi_${timestamp}_$seed.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
