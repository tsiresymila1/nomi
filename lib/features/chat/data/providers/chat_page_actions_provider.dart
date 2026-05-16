import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_model_switching_provider.dart';
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/providers/selected_chat_provider.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/providers/download_notifier.dart';

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
    ref.read(chatModelSwitchingProvider.notifier).start();
    ref.invalidate(activeGemmaChatProvider);
    try {
      await ref.read(downloadProvider.notifier).installModel(model);
      ref.invalidate(activeModelInfoProvider);
      ref.invalidate(activeGemmaChatProvider);
    } finally {
      ref.read(chatModelSwitchingProvider.notifier).stop();
    }
  }
}
