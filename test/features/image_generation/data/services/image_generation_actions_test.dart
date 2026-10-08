import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/presentation/cubit/selected_chat_cubit.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/services/image_generation_actions.dart';
import 'package:gena/features/image_generation/data/services/local_image_generation_service.dart';

void main() {
  late db.GenaDatabase database;
  late _FakeSelectedChatCubit selectedChatCubit;
  late _FakeImageGenerationService service;
  late ImageGenerationActions actions;

  setUp(() async {
    database = db.GenaDatabase(NativeDatabase.memory());
    final workspaceId = await database
        .into(database.workspaces)
        .insert(db.WorkspacesCompanion.insert(name: 'Workspace'));
    final chatId = await database
        .into(database.chats)
        .insert(
          db.ChatsCompanion.insert(workspace: workspaceId, title: 'New chat'),
        );
    selectedChatCubit = _FakeSelectedChatCubit('$chatId');
    service = _FakeImageGenerationService();
    actions = ImageGenerationActions(
      database: database,
      selectedChatCubit: selectedChatCubit,
      service: service,
    );
  });

  tearDown(() => database.close());

  test(
    'persists the prompt followed by the generated assistant image',
    () async {
      final artifact = await actions.generateAndPersist(
        prompt: 'A luminous baobab',
        seed: 42,
        onProgress: (_) {},
      );

      final rows = await database.select(database.messages).get();
      expect(rows, hasLength(2));
      expect(rows.first.role, 'user');
      expect(rows.first.kind, 'text');
      expect(rows.first.content, 'A luminous baobab');
      expect(rows.last.role, 'assistant');
      expect(rows.last.kind, 'image');
      expect(rows.last.mediaPath, artifact.path);
      expect(rows.last.content, contains('SDXS-512'));
    },
  );

  test(
    'does not persist an orphaned image turn when generation fails',
    () async {
      service.error = StateError('generation failed');

      await expectLater(
        actions.generateAndPersist(prompt: 'A storm', onProgress: (_) {}),
        throwsA(isA<StateError>()),
      );

      final rows = await database.select(database.messages).get();
      expect(rows, isEmpty);
    },
  );

  test(
    'does not persist an orphaned image turn when generation is cancelled',
    () async {
      service.error = const ImageGenerationCancelledException();

      await expectLater(
        actions.generateAndPersist(
          prompt: 'A cancelled storm',
          onProgress: (_) {},
        ),
        throwsA(isA<ImageGenerationCancelledException>()),
      );

      final rows = await database.select(database.messages).get();
      expect(rows, isEmpty);
    },
  );

  test('rejects generation when no valid chat is selected', () async {
    selectedChatCubit.selected = null;

    await expectLater(
      actions.generateAndPersist(prompt: 'No chat', onProgress: (_) {}),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeSelectedChatCubit extends Fake implements SelectedChatCubit {
  _FakeSelectedChatCubit(this.selected);

  String? selected;

  @override
  String? get state => selected;
}

class _FakeImageGenerationService implements ImageGenerationServiceApi {
  Object? error;

  @override
  Future<void> cancelInstall() async {}

  @override
  void cancelGeneration() {}

  @override
  Future<ImageRuntimeSupport> checkSupport() async =>
      const ImageRuntimeSupport(isSupported: true);

  @override
  Future<GeneratedImageArtifact> generate({
    required String prompt,
    String negativePrompt = '',
    int width = 512,
    int height = 512,
    int? seed,
    void Function(LocalImageGenerationProgress progress)? onProgress,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    return GeneratedImageArtifact(
      path: '/generated/${seed ?? 3}.png',
      seed: seed ?? 3,
      width: width,
      height: height,
      elapsed: const Duration(seconds: 1),
    );
  }

  @override
  Future<InstalledImageModel> installModel({
    required void Function(double progress) onProgress,
    required void Function() onVerifying,
  }) async => const InstalledImageModel(
    profile: ImageModelProfile.sdxs,
    modelPath: '/models/sdxs.gguf',
  );

  @override
  Future<void> releaseEngine() async {}

  @override
  Future<void> removeModel() async {}

  @override
  Future<InstalledImageModel?> resolveModel() async =>
      const InstalledImageModel(
        profile: ImageModelProfile.sdxs,
        modelPath: '/models/sdxs.gguf',
      );
}
