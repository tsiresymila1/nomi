import 'package:drift/drift.dart';
import 'package:gena/core/prompt.dart';
part 'gena_database.g.dart';

mixin TableMixin on Table {
  late final id = integer().autoIncrement()();
  late final createdAt = dateTime().withDefault(currentDateAndTime)();
}

class Chats extends Table with TableMixin {
  late final workspace = integer().references(Workspaces, #id)();
  late final title = text().withLength(min: 6, max: 32)();
}

class Workspaces extends Table with TableMixin {
  late final name = text().withLength(min: 1, max: 64)();
  late final generalInstruction = text().withDefault(Constant(systemPrompt))();
  late final ragEnabled = boolean().withDefault(const Constant(false))();
  late final nativeToolsEnabled = boolean().withDefault(const Constant(true))();
  late final nativeOpenUrlEnabled = boolean().withDefault(
    const Constant(true),
  )();
  late final nativeOpenAppEnabled = boolean().withDefault(
    const Constant(true),
  )();
  late final nativeSendEmailEnabled = boolean().withDefault(
    const Constant(true),
  )();
  late final nativeFlashlightEnabled = boolean().withDefault(
    const Constant(true),
  )();
}

class WorkspaceDocuments extends Table with TableMixin {
  late final workspace = integer().references(Workspaces, #id)();
  late final name = text().withLength(min: 1, max: 160)();
  late final sourceType = text()();
  late final sourcePath = text()();
  late final content = text()();
  late final ingestionStatus = text().withDefault(const Constant('ready'))();
  late final ingestionError = text().nullable()();
  late final chunkCount = integer().withDefault(const Constant(0))();
}

class Messages extends Table with TableMixin {
  late final chat = integer().references(Chats, #id)();
  late final role = text()();
  late final kind = text().withDefault(const Constant('text'))();
  late final content = text()();
  late final mediaPath = text().nullable()();
}

class Models extends Table with TableMixin {
  late final name = text().withLength(min: 1, max: 64)();
  late final description = text()();
  late final modelId = text().nullable()();
  late final provider = text().withDefault(const Constant('local'))();
  late final apiUrl = text().nullable()();
  late final apiToken = text().nullable()();
  late final modelType = text()();
  late final supportImage = boolean().withDefault(const Constant(false))();
  late final supportAudio = boolean().withDefault(const Constant(false))();
  late final supportsFunctionCalls = boolean().withDefault(
    const Constant(false),
  )();
  late final isThinking = boolean().withDefault(const Constant(false))();
  late final temperature = real().withDefault(const Constant(0.8))();
  late final topK = integer().withDefault(const Constant(40))();
  late final topP = real().withDefault(const Constant(0.95))();
  late final maxTokens = integer().withDefault(const Constant(2048))();
  late final tokenBuffer = integer().withDefault(const Constant(256))();
  late final randomSeed = integer().withDefault(const Constant(1))();
  late final preferredBackend = text().withDefault(const Constant('gpu'))();
  late final sourceType = text()();
  late final source = text()();
}

@DriftDatabase(
  tables: [Workspaces, WorkspaceDocuments, Chats, Messages, Models],
)
class GenaDatabase extends _$GenaDatabase {
  GenaDatabase(super.e);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(models);
      }
      if (from < 3) {
        await m.addColumn(messages, messages.kind);
        await m.addColumn(messages, messages.mediaPath);
      }
      if (from < 4) {
        await m.addColumn(models, models.supportImage);
        await m.addColumn(models, models.supportAudio);
        await m.addColumn(models, models.supportsFunctionCalls);
        await m.addColumn(models, models.isThinking);
      }
      if (from < 5) {
        await m.addColumn(models, models.modelId);
      }
      if (from < 6) {
        await m.createTable(workspaces);
        await m.addColumn(chats, chats.workspace);
        final workspaceId = await into(workspaces).insert(
          WorkspacesCompanion.insert(
            name: 'My workspace',
            generalInstruction: const Value(systemPrompt),
          ),
        );
        await customStatement(
          'UPDATE chats SET workspace = ? WHERE workspace IS NULL',
          [workspaceId],
        );
      }
      if (from < 7) {
        await m.addColumn(models, models.temperature);
        await m.addColumn(models, models.topK);
        await m.addColumn(models, models.topP);
        await m.addColumn(models, models.maxTokens);
        await m.addColumn(models, models.tokenBuffer);
        await m.addColumn(models, models.randomSeed);
        await m.addColumn(models, models.preferredBackend);
      }
      if (from < 8) {
        await m.addColumn(workspaces, workspaces.ragEnabled);
        await m.createTable(workspaceDocuments);
      }
      if (from < 9) {
        await m.addColumn(
          workspaceDocuments,
          workspaceDocuments.ingestionStatus,
        );
        await m.addColumn(
          workspaceDocuments,
          workspaceDocuments.ingestionError,
        );
        await m.addColumn(workspaceDocuments, workspaceDocuments.chunkCount);
        await customStatement(
          "UPDATE workspace_documents SET ingestion_status = 'ready' WHERE ingestion_status IS NULL OR TRIM(ingestion_status) = ''",
        );
      }
      if (from < 10) {
        await m.addColumn(workspaces, workspaces.nativeToolsEnabled);
        await customStatement(
          'UPDATE workspaces SET native_tools_enabled = 1 WHERE native_tools_enabled IS NULL OR native_tools_enabled = 0',
        );
      }
      if (from < 11) {
        await m.addColumn(workspaces, workspaces.nativeOpenUrlEnabled);
        await m.addColumn(workspaces, workspaces.nativeOpenAppEnabled);
        await m.addColumn(workspaces, workspaces.nativeSendEmailEnabled);
        await m.addColumn(workspaces, workspaces.nativeFlashlightEnabled);
        await customStatement(
          'UPDATE workspaces '
          'SET native_tools_enabled = 1, '
          'native_open_url_enabled = 1, '
          'native_open_app_enabled = 1, '
          'native_send_email_enabled = 1, '
          'native_flashlight_enabled = 1',
        );
      }
      if (from < 12) {
        await m.addColumn(models, models.provider);
        await m.addColumn(models, models.apiUrl);
        await m.addColumn(models, models.apiToken);
        await customStatement(
          "UPDATE models SET provider = 'local' WHERE provider IS NULL OR TRIM(provider) = ''",
        );
      }
    },
  );
}
