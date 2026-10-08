import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';

abstract interface class ImageGenerationActionsApi {
  Future<ImageRuntimeSupport> checkSupport();

  Future<InstalledImageModel?> resolveModel();

  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  });

  Future<void> cancelInstall();

  Future<GeneratedImageArtifact> generateAndPersist({
    required String prompt,
    int? seed,
    required void Function(LocalImageGenerationProgress progress) onProgress,
  });

  void cancelGeneration();

  Future<void> removeModel();
}

class ImageGenerationActions implements ImageGenerationActionsApi {
  const ImageGenerationActions({
    required db.GenaDatabase database,
    required SelectedChatCubit selectedChatCubit,
    required ImageGenerationServiceApi service,
  }) : _database = database,
       _selectedChatCubit = selectedChatCubit,
       _service = service;

  final db.GenaDatabase _database;
  final SelectedChatCubit _selectedChatCubit;
  final ImageGenerationServiceApi _service;

  @override
  Future<ImageRuntimeSupport> checkSupport() => _service.checkSupport();

  @override
  Future<InstalledImageModel?> resolveModel() => _service.resolveModel();

  @override
  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) => _service.installModel(onProgress: onProgress, onVerifying: onVerifying);

  @override
  Future<void> cancelInstall() => _service.cancelInstall();

  @override
  Future<GeneratedImageArtifact> generateAndPersist({
    required String prompt,
    int? seed,
    required void Function(LocalImageGenerationProgress progress) onProgress,
  }) async {
    final chatId = int.tryParse(_selectedChatCubit.state ?? '');
    if (chatId == null) throw StateError('Select a chat before generating.');
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'must not be empty');
    }

    await storeUserMessage(
      database: _database,
      chatId: chatId,
      text: normalizedPrompt,
      hasImage: false,
      imagePath: null,
    );
    await updateThreadTitleFromFirstMessage(
      database: _database,
      chatId: chatId,
      messageText: normalizedPrompt,
      hasImage: true,
    );

    final artifact = await _service.generate(
      prompt: normalizedPrompt,
      seed: seed,
      onProgress: onProgress,
    );
    final seconds = (artifact.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    await _database
        .into(_database.messages)
        .insert(
          db.MessagesCompanion.insert(
            chat: chatId,
            role: 'assistant',
            kind: const Value('image'),
            content:
                'Generated locally with ${ImageModelProfile.sdxs.name} '
                '· seed ${artifact.seed} · ${seconds}s',
            mediaPath: Value(artifact.path),
          ),
        );
    return artifact;
  }

  @override
  void cancelGeneration() => _service.cancelGeneration();

  @override
  Future<void> removeModel() => _service.removeModel();
}
