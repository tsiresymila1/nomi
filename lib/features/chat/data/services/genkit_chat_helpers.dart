import 'dart:convert';

import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/tools/chat_tools.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_openai/genkit_openai.dart';

/// Builds the list of Genkit [Message]s sent to the model from the stored
/// conversation rows.
///
/// A leading system message is added when [systemInstruction] is non-blank.
/// User text rows become user messages; user image rows additionally append a
/// [MediaPart] pointing at the local file. Assistant `text` rows become model
/// messages. All other rows (thinking, tool traces, tool calls, etc.) are
/// filtered out, and rows with no resulting content are skipped.
List<Message> buildGenkitMessages({
  required String systemInstruction,
  required List<db.Message> storedMessages,
  Map<int, List<db.MessageAttachment>> storedAttachmentsByMessageId = const {},
}) {
  final messages = <Message>[];

  final trimmedSystem = systemInstruction.trim();
  if (trimmedSystem.isNotEmpty) {
    messages.add(
      Message(
        role: Role.system,
        content: [TextPart(text: trimmedSystem)],
      ),
    );
  }

  for (final message in storedMessages) {
    if (!isGenkitConversationMessage(message)) continue;

    if (message.role == 'user') {
      final content = <Part>[];
      final attachments = storedAttachmentsByMessageId[message.id] ?? const [];
      final text = message.content.trim();
      if (text.isNotEmpty) {
        content.add(TextPart(text: text));
      }

      final hasPersistedImage = attachments.any(
        (attachment) => attachment.kind == 'image',
      );
      if (message.kind == 'image' && !hasPersistedImage) {
        final mediaPath = (message.mediaPath ?? '').trim();
        if (mediaPath.isNotEmpty) {
          final mediaUri = Uri.file(mediaPath).toString();
          content.add(
            MediaPart(
              media: Media(contentType: 'image/*', url: mediaUri),
            ),
          );
        }
      }

      for (final attachment in attachments) {
        final path = attachment.path.trim();
        if (attachment.kind == 'image' && path.isNotEmpty) {
          content.add(
            MediaPart(
              media: Media(
                contentType: _imageContentType(attachment.sourceType),
                url: Uri.file(path).toString(),
              ),
            ),
          );
          continue;
        }

        if (attachment.kind == 'document') {
          final documentText = attachment.extractedText?.trim() ?? '';
          if (documentText.isEmpty) continue;
          content.add(
            TextPart(
              text:
                  '--- BEGIN ATTACHMENT: ${attachment.name} ---\n'
                  '$documentText\n'
                  '--- END ATTACHMENT: ${attachment.name} ---',
            ),
          );
          continue;
        }

        if (attachment.kind == 'audio') {
          final transcript = attachment.extractedText?.trim() ?? '';
          if (transcript.isEmpty) continue;
          content.add(
            TextPart(
              text:
                  '--- BEGIN AUDIO TRANSCRIPT: ${attachment.name} ---\n'
                  '$transcript\n'
                  '--- END AUDIO TRANSCRIPT: ${attachment.name} ---',
            ),
          );
        }
      }

      if (content.isEmpty) continue;
      messages.add(Message(role: Role.user, content: content));
      continue;
    }

    if (message.role == 'assistant' && message.kind == 'text') {
      final text = message.content.trim();
      if (text.isEmpty) continue;
      messages.add(
        Message(
          role: Role.model,
          content: [TextPart(text: text)],
        ),
      );
    }
  }

  return messages;
}

String _imageContentType(String sourceType) {
  final normalized = sourceType.trim().toLowerCase();
  return switch (normalized) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/*',
  };
}

/// Whether a stored row is part of the user/model conversation (text or image),
/// as opposed to internal rows like thinking or tool traces.
bool isGenkitConversationMessage(db.Message message) {
  final isConversationRole =
      message.role == 'user' || message.role == 'assistant';
  final isConversationKind = message.kind == 'text' || message.kind == 'image';
  return isConversationRole && isConversationKind;
}

/// Resolves the provider-specific generation config for [activeModel].
///
/// Local models map onto a [LlamaDartGenerationConfig], remote models onto an
/// [OpenAIChatOptions].
Object resolveModelConfig({required ModelInfo activeModel}) {
  if (activeModel.provider == ModelProviderType.local) {
    return LlamaDartGenerationConfig(
      temperature: activeModel.temperature,
      topP: activeModel.topP,
      topK: activeModel.topK,
      maxTokens: activeModel.tokenBuffer,
      seed: activeModel.randomSeed,
      enableThinking: activeModel.isThinking,
      parallelToolCalls: activeModel.supportsFunctionCalls,
    );
  }

  return OpenAIChatOptions(
    temperature: activeModel.temperature,
    topP: activeModel.topP,
    maxTokens: activeModel.tokenBuffer,
    seed: activeModel.randomSeed,
  );
}

/// Concatenates the reasoning text contained in [parts].
String extractReasoning(List<Part> parts) {
  final buffer = StringBuffer();
  for (final part in parts) {
    final json = part.toJson();
    final reasoning = json['reasoning'];
    if (reasoning is String && reasoning.isNotEmpty) {
      buffer.write(reasoning);
    }
  }
  return buffer.toString();
}

/// Resolves the remote model identifier, preferring [ModelInfo.modelId] then
/// falling back to [ModelInfo.name]. Throws when neither is available.
String resolveRemoteModelId(ModelInfo model) {
  final modelId = (model.modelId ?? '').trim();
  if (modelId.isNotEmpty) return modelId;

  final name = model.name.trim();
  if (name.isNotEmpty) return name;

  throw StateError('Remote model id is missing.');
}

/// Normalizes an API key, stripping a leading `bearer ` prefix if present.
String normalizeApiKey(String apiToken) {
  final trimmed = apiToken.trim();
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.substring(7).trim();
  }
  return trimmed;
}

/// Normalizes a base URL: validates http(s) scheme, strips trailing slashes and
/// a trailing `/chat/completions` suffix. Throws on empty or invalid input.
String normalizeBaseUrl(String input) {
  if (input.isEmpty) {
    throw StateError('Remote model is missing API URL.');
  }

  final uri = Uri.tryParse(input);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw StateError('Invalid API URL: $input');
  }

  var normalized = input.replaceAll(RegExp(r'/+$'), '');
  if (normalized.endsWith('/chat/completions')) {
    normalized = normalized.substring(0, normalized.length - 17);
  }

  if (normalized.isEmpty) {
    throw StateError('Invalid API URL: $input');
  }

  return normalized;
}

/// Compacts a raw tool [result] map for inclusion in a model prompt.
///
/// When [stringifyForGemma4LiteRt] is set, the result is sanitized and then
/// rendered to a single text blob (Gemma 4 LiteRT does not accept nested tool
/// result objects). Web search results get a dedicated compaction; everything
/// else is depth/size limited via [sanitizeMap].
Map<String, dynamic> compactToolResultForModel({
  required String toolName,
  required Map<String, dynamic> result,
  required bool stringifyForGemma4LiteRt,
}) {
  if (stringifyForGemma4LiteRt) {
    final compact = sanitizeMap(
      result,
      maxDepth: 4,
      maxStringChars: 700,
      maxMapEntries: 16,
      maxListItems: 8,
    );
    return <String, dynamic>{'result': renderToolResultText(toolName, compact)};
  }

  if (toolName == webSearchToolName) {
    return compactWebSearchResult(result);
  }
  return sanitizeMap(
    result,
    maxDepth: 5,
    maxStringChars: 1200,
    maxMapEntries: 24,
    maxListItems: 12,
  );
}

/// Compacts a web search result: keeps at most 5 entries (title/url/source/
/// published/body), truncates each body to 360 chars and the summary to 700.
Map<String, dynamic> compactWebSearchResult(Map<String, dynamic> result) {
  final output = Map<String, dynamic>.from(result);
  final rawData = result['data'];
  if (rawData is List) {
    final compactItems = <Map<String, dynamic>>[];
    for (final entry in rawData.take(5)) {
      if (entry is! Map) continue;
      final source = entry.map((key, value) => MapEntry(key.toString(), value));
      compactItems.add(<String, dynamic>{
        if (source['title'] != null) 'title': source['title'],
        if (source['url'] != null) 'url': source['url'],
        if (source['source'] != null) 'source': source['source'],
        if (source['published'] != null) 'published': source['published'],
        if (source['body'] != null)
          'body': truncate(source['body'].toString(), 360),
      });
    }
    output['data'] = compactItems;
    output['count'] = compactItems.length;
  }

  final summary = result['summary'];
  if (summary is String) {
    output['summary'] = truncate(summary, 700);
  }

  return output;
}

/// Recursively sanitizes [input], truncating long strings and capping the
/// number of map entries, list items, and nesting depth.
dynamic sanitizeMap(
  dynamic input, {
  required int maxDepth,
  required int maxStringChars,
  required int maxMapEntries,
  required int maxListItems,
}) {
  if (input == null || maxDepth <= 0) {
    return input;
  }

  if (input is String) {
    return truncate(input, maxStringChars);
  }

  if (input is num || input is bool) {
    return input;
  }

  if (input is List) {
    final result = <dynamic>[];
    for (final value in input.take(maxListItems)) {
      result.add(
        sanitizeMap(
          value,
          maxDepth: maxDepth - 1,
          maxStringChars: maxStringChars,
          maxMapEntries: maxMapEntries,
          maxListItems: maxListItems,
        ),
      );
    }
    if (input.length > maxListItems) {
      result.add('...(${input.length - maxListItems} more item(s))');
    }
    return result;
  }

  if (input is Map) {
    final output = <String, dynamic>{};
    var count = 0;
    for (final entry in input.entries) {
      if (count >= maxMapEntries) {
        output['__truncated__'] =
            '${input.length - maxMapEntries} more key(s) omitted';
        break;
      }
      output[entry.key.toString()] = sanitizeMap(
        entry.value,
        maxDepth: maxDepth - 1,
        maxStringChars: maxStringChars,
        maxMapEntries: maxMapEntries,
        maxListItems: maxListItems,
      );
      count++;
    }
    return output;
  }

  return truncate(input.toString(), maxStringChars);
}

/// Truncates [value] to [maxLength] characters, appending `...` when cut.
String truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}...';
}

/// Whether tool results should be flattened to text for Gemma 4 LiteRT.
///
/// True only for local `gemma4` models whose source ends with `.litertlm`.
bool shouldStringifyToolResultForGemma4LiteRt(ModelInfo model) {
  if (model.provider != ModelProviderType.local) return false;
  if (model.modelType.toLowerCase() != 'gemma4') return false;
  return model.source.toLowerCase().endsWith('.litertlm');
}

/// Collects non-empty rendered tool result texts to build an assistant
/// fallback message when the model returns no final text.
class ToolResultCollector {
  final List<String> _entries = [];

  bool get hasEntries => _entries.isNotEmpty;

  void add(String resultText) {
    final normalized = resultText.trim();
    if (normalized.isEmpty) return;
    _entries.add(normalized);
  }

  String buildAssistantFallback() {
    return _entries.join('\n\n').trim();
  }
}

/// Renders a tool [result] as a human-readable `Tool result: <name>` block.
String renderToolResultText(String toolName, dynamic result) {
  final buffer = StringBuffer('Tool result: $toolName');
  final rendered = renderToolValueText(result);
  if (rendered.isNotEmpty) {
    buffer
      ..write('\n')
      ..write(rendered);
  }
  return buffer.toString().trim();
}

/// Renders a dynamic tool value as indented plain text (maps, lists, scalars).
String renderToolValueText(dynamic value, {int indent = 0}) {
  final prefix = '  ' * indent;

  if (value == null) return '${prefix}null';
  if (value is String || value is num || value is bool) {
    return '$prefix$value';
  }

  if (value is List) {
    if (value.isEmpty) return '$prefix[]';
    final lines = <String>[];
    for (final item in value) {
      if (item is Map || item is List) {
        lines.add('$prefix-');
        lines.add(renderToolValueText(item, indent: indent + 1));
      } else {
        lines.add('$prefix- ${renderInlineToolValue(item)}');
      }
    }
    return lines.join('\n');
  }

  if (value is Map) {
    if (value.isEmpty) return '$prefix{}';
    final lines = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final entryValue = entry.value;
      if (entryValue is Map || entryValue is List) {
        lines.add('$prefix$key:');
        lines.add(renderToolValueText(entryValue, indent: indent + 1));
      } else {
        lines.add('$prefix$key: ${renderInlineToolValue(entryValue)}');
      }
    }
    return lines.join('\n');
  }

  return '$prefix$value';
}

/// Renders a scalar/inline tool value, JSON-encoding complex values.
String renderInlineToolValue(dynamic value) {
  if (value == null) return 'null';
  if (value is String || value is num || value is bool) {
    return value.toString();
  }
  return jsonEncode(value);
}
