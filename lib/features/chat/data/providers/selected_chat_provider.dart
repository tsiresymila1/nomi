import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/core/database/gena_provider.dart';

final selectedChatIdProvider =
    NotifierProvider<SelectedChatIdNotifier, String?>(
      SelectedChatIdNotifier.new,
    );

class SelectedChatIdNotifier extends Notifier<String?> {
  bool _initialized = false;

  @override
  String? build() {
    _hydrateInitialSelection();
    return null;
  }

  Future<void> _hydrateInitialSelection() async {
    if (_initialized) return;
    _initialized = true;

    final database = ref.read(genaDatabaseProvider);
    final firstChat =
        await (database.select(database.chats)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (firstChat != null) {
      state = firstChat.id.toString();
      return;
    }

    await createNewThread();
  }

  Future<String> createNewThread() async {
    final database = ref.read(genaDatabaseProvider);
    final createdId = await database
        .into(database.chats)
        .insert(db.ChatsCompanion.insert(title: 'New chat'));

    final selectedId = createdId.toString();
    state = selectedId;
    return selectedId;
  }

  void selectChat(String? chatId) {
    if (chatId == state) return;
    state = chatId;
  }
}
