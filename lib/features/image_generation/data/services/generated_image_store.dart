import 'package:gena/features/image_generation/data/services/generated_image_store_stub.dart'
    if (dart.library.io) 'package:gena/features/image_generation/data/services/generated_image_store_io.dart'
    as impl;
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';

GeneratedImageStore createGeneratedImageStore() =>
    impl.createPlatformGeneratedImageStore();
