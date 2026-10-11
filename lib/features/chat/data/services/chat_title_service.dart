import 'dart:async';

import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';
import 'package:gena/features/chat/data/services/genkit_chat_helpers.dart';
import 'package:gena/features/chat/data/services/remote_llm_service.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

const String _threadTitleSystemInstruction =
    'You generate concise chat titles. '
    'Use 3 to 7 words, maximum 32 characters. '
    'No quotes, no punctuation at start/end, no markdown. '
    'Return only the title text.';

void scheduleThreadTitleUpdate({
  required db.GenaDatabase database,
  required int chatId,
  required String messageText,
  required bool hasImage,
  required ModelInfo activeModel,
}) {
  updateThreadTitleFromFirstMessage(
    database: database,
    chatId: chatId,
    messageText: messageText,
    hasImage: hasImage,
    titleGenerator: (text, {required hasImage}) => _generateAiThreadTitle(
      activeModel: activeModel,
      messageText: text,
      hasImage: hasImage,
    ),
  ).ignore();
}

Future<String?> _generateAiThreadTitle({
  required ModelInfo activeModel,
  required String messageText,
  required bool hasImage,
}) async {
  final content = messageText.trim();
  if (content.isEmpty && !hasImage) return null;
  if (content.length > 1200) {
    return null;
  }

  try {
    if (activeModel.provider == ModelProviderType.remote) {
      if (usesAnthropicRemoteProtocol(activeModel)) return null;
      return await _generateRemoteThreadTitle(
        model: activeModel,
        messageText: content,
        hasImage: hasImage,
      ).timeout(const Duration(seconds: 5));
    }

    // A second local generation here replaces llamadart's prompt/KV cache with
    // an unrelated title prompt, forcing the next chat turn to replay the full
    // conversation. Local chats use the deterministic first-message fallback;
    // remote title generation does not touch the local runtime.
    return null;
  } catch (_) {
    return null;
  }
}

Future<String?> _generateRemoteThreadTitle({
  required ModelInfo model,
  required String messageText,
  required bool hasImage,
}) async {
  final userPrompt = _buildTitlePrompt(
    messageText: messageText,
    hasImage: hasImage,
  );
  final result = await runRemoteChatTurnStreamed(
    model: model,
    messages: [
      openai.ChatMessage.system(_threadTitleSystemInstruction),
      openai.ChatMessage.user(userPrompt),
    ],
    tools: const <openai.Tool>[],
  );
  return result.generatedText;
}

String _buildTitlePrompt({
  required String messageText,
  required bool hasImage,
}) {
  final safeText = messageText.trim();
  final imageHint = hasImage ? 'yes' : 'no';
  return 'Create a short conversation title for this first user message.\n'
      'Return title only.\n'
      'Message has image: $imageHint\n'
      'User message: $safeText';
}
