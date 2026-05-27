import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/providers/chat_session_provider.dart';
import 'package:gena/features/chat/data/services/chat_thread_execution_service.dart';
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
  required ChatSessionController sessionController,
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
      sessionController: sessionController,
      activeModel: activeModel,
      messageText: text,
      hasImage: hasImage,
    ),
  ).ignore();
}

Future<String?> _generateAiThreadTitle({
  required ChatSessionController sessionController,
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
      return await _generateRemoteThreadTitle(
        model: activeModel,
        messageText: content,
        hasImage: hasImage,
      ).timeout(const Duration(seconds: 5));
    }

    return await _generateLocalThreadTitle(
      sessionController: sessionController,
      messageText: content,
      hasImage: hasImage,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    return null;
  }
}

Future<String?> _generateRemoteThreadTitle({
  required ModelInfo model,
  required String messageText,
  required bool hasImage,
}) async {
  final userPrompt = _buildTitlePrompt(messageText: messageText, hasImage: hasImage);
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

Future<String?> _generateLocalThreadTitle({
  required ChatSessionController sessionController,
  required String messageText,
  required bool hasImage,
}) async {
  final runtime = await sessionController.getRuntime();
  if (runtime == null) return null;

  final session = await runtime.model.createSession(
    temperature: 0.2,
    randomSeed: runtime.randomSeed,
    topK: runtime.topK,
    topP: runtime.topP,
    systemInstruction: _threadTitleSystemInstruction,
  );

  try {
    await session.addQueryChunk(
      gemma.Message.text(
        text: _buildTitlePrompt(messageText: messageText, hasImage: hasImage),
        isUser: true,
      ),
    );
    final responseStream = session.getResponseAsync();
    final responseBuffer = StringBuffer();
    await for (final response in responseStream) {
      if (response is gemma.TextResponse) {
        responseBuffer.write(response);
      }
    }
    return responseBuffer.toString();
  } finally {
    await session.close();
  }
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
