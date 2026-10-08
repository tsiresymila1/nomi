import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/data/services/image_model_store_stub.dart'
    if (dart.library.io) 'package:gena/features/image_generation/data/services/image_model_store_io.dart'
    as impl;

ImageModelStore createImageModelStore() => impl.createPlatformImageModelStore();
