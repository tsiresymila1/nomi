import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/features/image_generation/data/services/generated_image_store.dart';
import 'package:gena/features/image_generation/data/services/image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/data/services/image_model_store_factory.dart';
import 'package:gena/features/image_generation/data/services/llamadart_image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';

void registerImageGenerationDependencies() {
  if (!sl.isRegistered<ImageModelStore>()) {
    sl.registerLazySingleton<ImageModelStore>(createImageModelStore);
  }
  if (!sl.isRegistered<ImageGenerationBackend>()) {
    sl.registerLazySingleton<ImageGenerationBackend>(
      LlamadartImageGenerationBackend.new,
    );
  }
  if (!sl.isRegistered<GeneratedImageStore>()) {
    sl.registerLazySingleton<GeneratedImageStore>(createGeneratedImageStore);
  }
  if (!sl.isRegistered<LocalImageGenerationService>()) {
    sl.registerLazySingleton<LocalImageGenerationService>(
      () => LocalImageGenerationService(
        coordinator: sl<LocalAiRuntimeCoordinator>(),
        modelStore: sl<ImageModelStore>(),
        backend: sl<ImageGenerationBackend>(),
        outputStore: sl<GeneratedImageStore>(),
      ),
    );
  }
}
