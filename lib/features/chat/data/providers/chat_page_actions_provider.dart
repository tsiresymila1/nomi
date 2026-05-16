import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/downloads/domain/model_info.dart';
import 'package:gena/features/downloads/presentation/providers/download_notifier.dart';

final chatPageActionsProvider = Provider<ChatPageActions>(
  (ref) => ChatPageActions(ref),
);

class ChatPageActions {
  final Ref ref;
  ChatPageActions(this.ref);

  Future<void> createNewThread() async {
    await ref.read(selectedChatIdProvider.notifier).createNewThread();
  }

  Future<void> installModel(ModelInfo model) async {
    await ref.read(downloadProvider.notifier).installModel(model);
    ref.invalidate(activeGemmaChatProvider);
  }
}
