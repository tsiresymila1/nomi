import 'dart:convert';

import 'package:flutter_gemma/core/function_call_parser.dart';
import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/providers/chat_ui_state_provider.dart';

class StreamingTurnResult {
  final List<gemma.FunctionCallResponse> toolCalls;
  final bool wasCancelled;

  const StreamingTurnResult({
    required this.toolCalls,
    this.wasCancelled = false,
  });
}

Future<StreamingTurnResult> runStreamingTurn({
  required Ref ref,
  required gemma.InferenceChat chat,
  required StringBuffer responseBuffer,
  required StringBuffer thinkingBuffer,
  required bool shouldHandleThinking,
  required gemma.ModelType modelType,
  bool Function()? isCancelled,
}) async {
  final turnTextBuffer = StringBuffer();
  final toolCalls = <gemma.FunctionCallResponse>[];
  var wasCancelled = false;

  await for (final response in chat.generateChatResponseAsync()) {
    if (isCancelled?.call() ?? false) {
      wasCancelled = true;
      break;
    }

    if (response is gemma.TextResponse) {
      turnTextBuffer.write(response.token);
      final preview = sanitizeToolMarkupForDisplay(
        turnTextBuffer.toString(),
        stripTrailingOpenTag: true,
      );
      ref
          .read(chatDraftResponseProvider.notifier)
          .setDraft(responseBuffer.toString() + preview);
      continue;
    }

    if (response is gemma.ThinkingResponse && shouldHandleThinking) {
      thinkingBuffer.write(response.content);
      ref
          .read(chatDraftThinkingProvider.notifier)
          .setDraft(thinkingBuffer.toString());
      continue;
    }

    if (response is gemma.FunctionCallResponse) {
      toolCalls.add(response);
      continue;
    }

    if (response is gemma.ParallelFunctionCallResponse) {
      toolCalls.addAll(response.calls);
      continue;
    }
  }

  final turnText = turnTextBuffer.toString();
  if (toolCalls.isEmpty && turnText.contains('<|tool_call>')) {
    final parsedToolCalls = FunctionCallParser.parseAll(
      turnText,
      modelType: modelType,
    );
    toolCalls.addAll(parsedToolCalls);
  }

  if (wasCancelled) {
    return const StreamingTurnResult(
      toolCalls: <gemma.FunctionCallResponse>[],
      wasCancelled: true,
    );
  }

  final visibleTurnText = sanitizeToolMarkupForDisplay(turnText);
  responseBuffer.write(visibleTurnText);
  ref
      .read(chatDraftResponseProvider.notifier)
      .setDraft(responseBuffer.toString());
  return StreamingTurnResult(toolCalls: toolCalls);
}

String sanitizeToolMarkupForDisplay(
  String text, {
  bool stripTrailingOpenTag = false,
}) {
  var sanitized = text.replaceAll(
    RegExp(r'<\|tool_call\>[\s\S]*?<tool_call\|>', multiLine: true),
    '',
  );

  if (stripTrailingOpenTag) {
    final openIndex = sanitized.lastIndexOf('<|tool_call>');
    final closeIndex = sanitized.lastIndexOf('<tool_call|>');
    if (openIndex != -1 && openIndex > closeIndex) {
      sanitized = sanitized.substring(0, openIndex);
    }
  }
  sanitized = sanitized.replaceAll('<|"|>', '"');
  try {
    jsonDecode(sanitized);
    return "";
  } catch (e) {
    return sanitized;
  }
}
