import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/features/chat/data/models/chat_attachment.dart';
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildSystemInstruction', () {
    test('returns only date context when base prompt is empty', () {
      final result = buildSystemInstruction('   ');
      expect(result, startsWith('CURRENT LOCAL DATE CONTEXT'));
      expect(result, contains('Today is'));
      expect(result, contains('Local timezone:'));
    });

    test('prepends the base prompt and appends date context', () {
      final result = buildSystemInstruction('Be concise.');
      expect(result, startsWith('Be concise.'));
      expect(result, contains('CURRENT LOCAL DATE CONTEXT'));
    });
  });

  group('Drift-backed helpers', () {
    late GenaDatabase database;

    setUp(() => database = GenaDatabase(NativeDatabase.memory()));
    tearDown(() => database.close());

    Future<int> newThread({String title = 'New chat'}) async {
      final workspaceId = await database
          .into(database.workspaces)
          .insert(WorkspacesCompanion.insert(name: 'Test workspace'));
      return database
          .into(database.chats)
          .insert(ChatsCompanion.insert(workspace: workspaceId, title: title));
    }

    test('storeUserMessage persists a text message', () async {
      final chatId = await newThread();
      final messageId = await storeUserMessage(
        database: database,
        chatId: chatId,
        text: 'hello',
        hasImage: false,
        imagePath: null,
      );

      final rows = await database.select(database.messages).get();
      expect(rows, hasLength(1));
      expect(messageId, rows.single.id);
      expect(rows.single.role, 'user');
      expect(rows.single.kind, 'text');
      expect(rows.single.content, 'hello');
      expect(rows.single.mediaPath, isNull);
    });

    test('storeUserMessage records an image attachment', () async {
      final chatId = await newThread();
      await storeUserMessage(
        database: database,
        chatId: chatId,
        text: 'look',
        hasImage: true,
        imagePath: '/tmp/p.png',
      );

      final row = (await database.select(database.messages).get()).single;
      expect(row.kind, 'image');
      expect(row.mediaPath, '/tmp/p.png');
    });

    test(
      'storeUserMessage persists multiple typed attachments atomically',
      () async {
        final chatId = await newThread();
        final messageId = await storeUserMessage(
          database: database,
          chatId: chatId,
          text: 'review these',
          hasImage: true,
          imagePath: '/app/one.png',
          attachments: const [
            PreparedChatAttachment(
              id: 'image-1',
              name: 'one.png',
              kind: ChatAttachmentKind.image,
              sourceType: 'png',
              appPath: '/app/one.png',
              sizeBytes: 4,
            ),
            PreparedChatAttachment(
              id: 'doc-1',
              name: 'notes.txt',
              kind: ChatAttachmentKind.document,
              sourceType: 'text',
              appPath: '/app/notes.txt',
              sizeBytes: 12,
              extractedText: 'document body',
            ),
          ],
        );

        final rows = await (database.select(
          database.messageAttachments,
        )..where((row) => row.message.equals(messageId))).get();
        expect(rows, hasLength(2));
        expect(rows.map((row) => row.kind), containsAll(['image', 'document']));
        expect(rows.last.extractedText, 'document body');
      },
    );

    test(
      'updateThreadTitleFromFirstMessage uses the generated title',
      () async {
        final chatId = await newThread();
        await updateThreadTitleFromFirstMessage(
          database: database,
          chatId: chatId,
          messageText: 'whatever',
          hasImage: false,
          titleGenerator: (text, {required hasImage}) async =>
              'Generated Title',
        );

        final chat = await (database.select(
          database.chats,
        )..where((t) => t.id.equals(chatId))).getSingle();
        expect(chat.title, 'Generated Title');
      },
    );

    test('falls back to a derived title when generation fails', () async {
      final chatId = await newThread();
      await updateThreadTitleFromFirstMessage(
        database: database,
        chatId: chatId,
        messageText: 'please summarize the quarterly report',
        hasImage: false,
        titleGenerator: (text, {required hasImage}) async =>
            throw StateError('boom'),
      );

      final chat = await (database.select(
        database.chats,
      )..where((t) => t.id.equals(chatId))).getSingle();
      expect(chat.title, isNot('New chat'));
      expect(chat.title.toLowerCase(), isNot(startsWith('please')));
    });

    test('keeps fallback image titles within the database limit', () async {
      final chatId = await newThread();
      await updateThreadTitleFromFirstMessage(
        database: database,
        chatId: chatId,
        messageText:
            'Créer moi un chat qui fait une très longue image fantastique',
        hasImage: true,
      );

      final chat = await (database.select(
        database.chats,
      )..where((t) => t.id.equals(chatId))).getSingle();
      expect(chat.title, endsWith('(image)'));
      expect(chat.title.length, lessThanOrEqualTo(32));
    });

    test('does not rename a thread that already has a custom title', () async {
      final chatId = await newThread(title: 'My custom title');
      await updateThreadTitleFromFirstMessage(
        database: database,
        chatId: chatId,
        messageText: 'hello there',
        hasImage: false,
        titleGenerator: (text, {required hasImage}) async => 'Generated',
      );

      final chat = await (database.select(
        database.chats,
      )..where((t) => t.id.equals(chatId))).getSingle();
      expect(chat.title, 'My custom title');
    });
  });
}
