import 'package:drift/drift.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/prompt.dart';
import 'package:gena/features/chat/data/models/chat_entity.dart';
import 'package:gena/features/chat/data/models/message_entity.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/workspace/data/models/workspace_chat_group.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';

const String defaultWorkspaceName = 'My workspace';

class ChatRepository {
  ChatRepository(this._database);

  final db.GenaDatabase _database;

  db.GenaDatabase get database => _database;

  Stream<List<ModelInfo>> watchModels() {
    final query = _database.select(_database.models)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ModelInfo(
              id: row.id,
              name: row.name,
              description: row.description,
              modelId: row.modelId,
              provider: row.provider,
              apiUrl: row.apiUrl,
              apiToken: row.apiToken,
              modelType: row.modelType,
              supportImage: row.supportImage,
              supportAudio: row.supportAudio,
              supportsFunctionCalls: row.supportsFunctionCalls,
              isThinking: row.isThinking,
              temperature: row.temperature,
              topK: row.topK,
              topP: row.topP,
              maxTokens: row.maxTokens,
              tokenBuffer: row.tokenBuffer,
              randomSeed: row.randomSeed,
              preferredBackend: row.preferredBackend,
              sourceType: row.sourceType,
              source: row.source,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<ChatEntity>> watchChats(String workspaceId) {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      return Stream.value(const <ChatEntity>[]);
    }

    final query = _database.select(_database.chats)
      ..where((t) => t.workspace.equals(parsedWorkspaceId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ChatEntity(
              id: row.id.toString(),
              workspaceId: row.workspace.toString(),
              title: row.title,
              createdAt: row.createdAt,
              updatedAt: row.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<MessageEntity>> watchMessages(String chatId) {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) {
      return Stream.value(const <MessageEntity>[]);
    }

    final query = _database.select(_database.messages)
      ..where((t) => t.chat.equals(parsedChatId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MessageEntity(
              id: row.id.toString(),
              chatId: row.chat.toString(),
              role: row.role,
              kind: row.kind,
              content: row.content,
              mediaPath: row.mediaPath,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<WorkspaceChatGroup>> watchWorkspaceChatGroups() {
    final joinQuery = _database.select(_database.workspaces).join([
      leftOuterJoin(
        _database.chats,
        _database.chats.workspace.equalsExp(_database.workspaces.id),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(_database.workspaces.createdAt),
        OrderingTerm.desc(_database.chats.createdAt),
      ]);

    return joinQuery.watch().map((rows) {
      final grouped = <int, WorkspaceChatGroup>{};

      for (final row in rows) {
        final workspaceRow = row.readTable(_database.workspaces);
        final workspaceId = workspaceRow.id;
        grouped.putIfAbsent(
          workspaceId,
          () => WorkspaceChatGroup(
            workspace: WorkspaceEntity(
              id: workspaceRow.id.toString(),
              name: workspaceRow.name,
              generalInstruction: workspaceRow.generalInstruction,
              ragEnabled: workspaceRow.ragEnabled,
              nativeToolsEnabled: workspaceRow.nativeToolsEnabled,
              nativeOpenUrlEnabled: workspaceRow.nativeOpenUrlEnabled,
              nativeOpenAppEnabled: workspaceRow.nativeOpenAppEnabled,
              nativeSendEmailEnabled: workspaceRow.nativeSendEmailEnabled,
              nativeFlashlightEnabled: workspaceRow.nativeFlashlightEnabled,
              createdAt: workspaceRow.createdAt,
            ),
            chats: <ChatEntity>[],
          ),
        );

        final chatRow = row.readTableOrNull(_database.chats);
        if (chatRow == null) continue;

        grouped[workspaceId]!.chats.add(
          ChatEntity(
            id: chatRow.id.toString(),
            workspaceId: chatRow.workspace.toString(),
            title: chatRow.title,
            createdAt: chatRow.createdAt,
            updatedAt: chatRow.createdAt,
          ),
        );
      }

      return grouped.values.toList(growable: false);
    });
  }

  Future<WorkspaceEntity?> getWorkspaceById(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return null;

    final row = await (_database.select(_database.workspaces)
          ..where((t) => t.id.equals(parsedWorkspaceId))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;

    return WorkspaceEntity(
      id: row.id.toString(),
      name: row.name,
      generalInstruction: row.generalInstruction,
      ragEnabled: row.ragEnabled,
      nativeToolsEnabled: row.nativeToolsEnabled,
      nativeOpenUrlEnabled: row.nativeOpenUrlEnabled,
      nativeOpenAppEnabled: row.nativeOpenAppEnabled,
      nativeSendEmailEnabled: row.nativeSendEmailEnabled,
      nativeFlashlightEnabled: row.nativeFlashlightEnabled,
      createdAt: row.createdAt,
    );
  }

  Future<String?> getFirstWorkspaceId() async {
    final firstWorkspace = await (_database.select(_database.workspaces)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return firstWorkspace?.id.toString();
  }

  Future<String> createDefaultWorkspaceIfNeeded() async {
    final existing = await getFirstWorkspaceId();
    if (existing != null) return existing;

    final id = await _database.into(_database.workspaces).insert(
          db.WorkspacesCompanion.insert(
            name: defaultWorkspaceName,
            generalInstruction: const Value(systemPrompt),
            nativeToolsEnabled: const Value(true),
            nativeOpenUrlEnabled: const Value(true),
            nativeOpenAppEnabled: const Value(true),
            nativeSendEmailEnabled: const Value(true),
            nativeFlashlightEnabled: const Value(true),
          ),
        );
    return id.toString();
  }

  Future<String> ensureWorkspace() async {
    return (await getFirstWorkspaceId()) ?? createDefaultWorkspaceIfNeeded();
  }

  Future<String?> findLatestChatIdForWorkspace(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) return null;

    final chat = await (_database.select(_database.chats)
          ..where((t) => t.workspace.equals(parsedWorkspaceId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return chat?.id.toString();
  }

  Future<bool> isChatInWorkspace({
    required String chatId,
    required String workspaceId,
  }) async {
    final parsedChatId = int.tryParse(chatId);
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedChatId == null || parsedWorkspaceId == null) return false;

    final chat = await (_database.select(_database.chats)
          ..where(
            (t) => t.id.equals(parsedChatId) & t.workspace.equals(parsedWorkspaceId),
          )
          ..limit(1))
        .getSingleOrNull();
    return chat != null;
  }

  Future<String> createNewChat(String workspaceId) async {
    final parsedWorkspaceId = int.tryParse(workspaceId);
    if (parsedWorkspaceId == null) {
      throw StateError('Invalid workspace id: $workspaceId');
    }

    final createdId = await _database.into(_database.chats).insert(
          db.ChatsCompanion.insert(title: 'New chat', workspace: parsedWorkspaceId),
        );
    return createdId.toString();
  }

  Future<void> deleteChat(String chatId) async {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return;

    await _database.transaction(() async {
      await (_database.delete(_database.messages)
            ..where((t) => t.chat.equals(parsedChatId)))
          .go();
      await (_database.delete(_database.chats)..where((t) => t.id.equals(parsedChatId)))
          .go();
    });
  }

  Future<int?> getChatWorkspaceId(String chatId) async {
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId == null) return null;

    final row = await (_database.select(_database.chats)
          ..where((t) => t.id.equals(parsedChatId))
          ..limit(1))
        .getSingleOrNull();
    return row?.workspace;
  }

  Future<void> updateActiveModelId(int? modelId) async {
    // Persistence handled by hydrated cubit. Method kept for API clarity.
    return;
  }
}
