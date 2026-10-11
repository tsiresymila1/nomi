import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/models/llamadart_tts_model_profile.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store_io.dart';

void main() {
  test('resolves an external TTS pair without copying it', () async {
    final directory = await Directory.systemTemp.createTemp('gena_tts_pair_');
    addTearDown(() => directory.delete(recursive: true));
    final model = File('${directory.path}/model.gguf');
    final projector = File('${directory.path}/mmproj.gguf');
    await model.writeAsBytes(<int>[1, 2, 3]);
    await projector.writeAsBytes(<int>[4, 5]);
    final profile = LlamaDartTtsModelProfile.external(
      name: 'Custom TTS',
      modelPath: model.path,
      modelSizeBytes: await model.length(),
      projectorPath: projector.path,
      projectorSizeBytes: await projector.length(),
    );

    final installed = await IoLlamaDartTtsModelStore().resolve(profile);

    expect(installed?.modelPath, model.path);
    expect(installed?.projectorPath, projector.path);
  });
}
