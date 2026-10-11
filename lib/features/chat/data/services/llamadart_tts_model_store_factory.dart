import 'package:gena/features/chat/data/services/llamadart_tts_model_store.dart';
import 'package:gena/features/chat/data/services/llamadart_tts_model_store_stub.dart'
    if (dart.library.io) 'package:gena/features/chat/data/services/llamadart_tts_model_store_io.dart'
    as impl;

LlamaDartTtsModelStore createLlamaDartTtsModelStore() =>
    impl.createPlatformLlamaDartTtsModelStore();
