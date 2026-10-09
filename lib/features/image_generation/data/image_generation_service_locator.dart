import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/local_ai/local_ai_runtime_coordinator.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/image_generation/data/services/generated_image_store.dart';
import 'package:gena/features/image_generation/data/services/image_generation_actions.dart';
import 'package:gena/features/image_generation/data/services/image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/image_model_store.dart';
import 'package:gena/features/image_generation/data/services/image_model_store_factory.dart';
import 'package:gena/features/image_generation/data/services/llamadart_image_generation_backend.dart';
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';
import 'package:gena/features/image_generation/presentation/cubit/chat_composer_mode_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_generation_cubit.dart';
import 'package:gena/features/image_generation/presentation/cubit/image_model_selection_cubit.dart';

void registerImageGenerationDependencies() {
  if (!sl.isRegistered<ImageModelSelectionCubit>()) {
    sl.registerLazySingleton<ImageModelSelectionCubit>(
      ImageModelSelectionCubit.new,
    );
  }
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
        selection: sl<ImageModelSelectionCubit>(),
      ),
    );
  }
  if (!sl.isRegistered<ImageGenerationActions>()) {
    sl.registerLazySingleton<ImageGenerationActions>(
      () => ImageGenerationActions(
        database: sl<GenaDatabase>(),
        selectedChatCubit: sl<SelectedChatCubit>(),
        service: sl<LocalImageGenerationService>(),
      ),
    );
  }
  if (!sl.isRegistered<ChatComposerModeCubit>()) {
    sl.registerLazySingleton<ChatComposerModeCubit>(ChatComposerModeCubit.new);
  }
  if (!sl.isRegistered<ImageGenerationCubit>()) {
    sl.registerLazySingleton<ImageGenerationCubit>(
      () => ImageGenerationCubit(
        sl<ImageGenerationActions>(),
        selection: sl<ImageModelSelectionCubit>(),
      ),
    );
  }
}
