import 'package:flutter_test/flutter_test.dart';
import 'package:gena/core/database/gena_database.dart' as db;
import 'package:gena/features/chat/data/services/genkit_chat_helpers.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:genkit/genkit.dart' hide ModelInfo;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_openai/genkit_openai.dart';

ModelInfo buildModel({
  String provider = ModelProviderType.local,
  String name = 'Test Model',
  String? modelId,
  String? apiUrl,
  String? apiToken,
  String modelType = 'gemma4',
  bool supportsFunctionCalls = true,
  bool isThinking = false,
  double temperature = 0.7,
  int topK = 40,
  double topP = 0.9,
  int maxTokens = 4096,
  int tokenBuffer = 512,
  int randomSeed = 123,
  String source = '/models/model.gguf',
}) {
  return ModelInfo(
    id: 1,
    name: name,
    description: 'desc',
    modelId: modelId,
    provider: provider,
    apiUrl: apiUrl,
    apiToken: apiToken,
    modelType: modelType,
    supportImage: false,
    supportAudio: false,
    supportsFunctionCalls: supportsFunctionCalls,
    isThinking: isThinking,
    temperature: temperature,
    topK: topK,
    topP: topP,
    maxTokens: maxTokens,
    tokenBuffer: tokenBuffer,
    randomSeed: randomSeed,
    preferredBackend: 'cpu',
    sourceType: 'file',
    source: source,
  );
}

db.Message buildMessage({
  int id = 1,
  required String role,
  required String kind,
  required String content,
  String? mediaPath,
}) {
  return db.Message(
    id: id,
    createdAt: DateTime.utc(2026, 1, 1),
    chat: 1,
    role: role,
    kind: kind,
    content: content,
    mediaPath: mediaPath,
  );
}

db.MessageAttachment buildAttachment({
  required int messageId,
  required String kind,
  required String name,
  required String sourceType,
  required String path,
  String? extractedText,
  int id = 1,
}) {
  return db.MessageAttachment(
    id: id,
    createdAt: DateTime.utc(2026, 1, 1),
    message: messageId,
    kind: kind,
    name: name,
    sourceType: sourceType,
    path: path,
    sizeBytes: 12,
    extractedText: extractedText,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildGenkitMessages', () {
    test('includes a system message when systemInstruction is non-blank', () {
      final messages = buildGenkitMessages(
        systemInstruction: 'Be concise.',
        storedMessages: const [],
      );
      expect(messages, hasLength(1));
      expect(messages.first.role, Role.system);
      expect(messages.first.content.first.text, 'Be concise.');
    });

    test('skips the system message when systemInstruction is blank', () {
      final messages = buildGenkitMessages(
        systemInstruction: '   ',
        storedMessages: const [],
      );
      expect(messages, isEmpty);
    });

    test('maps a user text row to a user Message', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(role: 'user', kind: 'text', content: 'Hello'),
        ],
      );
      expect(messages, hasLength(1));
      expect(messages.first.role, Role.user);
      expect(messages.first.content.single.text, 'Hello');
    });

    test('maps a user image row to text + media part with file uri', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(
            role: 'user',
            kind: 'image',
            content: 'Look at this',
            mediaPath: '/tmp/photo.png',
          ),
        ],
      );
      expect(messages, hasLength(1));
      final content = messages.first.content;
      expect(content, hasLength(2));
      expect(content[0].text, 'Look at this');
      expect(content[1].isMedia, isTrue);
      final media = content[1].media!;
      expect(media.contentType, 'image/*');
      expect(media.url, Uri.file('/tmp/photo.png').toString());
    });

    test('image row with blank media path yields only the text part', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(
            role: 'user',
            kind: 'image',
            content: 'No media',
            mediaPath: '   ',
          ),
        ],
      );
      expect(messages.first.content, hasLength(1));
      expect(messages.first.content.single.text, 'No media');
    });

    test(
      'maps multiple persisted images and a document into one user turn',
      () {
        final message = buildMessage(
          id: 9,
          role: 'user',
          kind: 'text',
          content: 'Compare these files',
        );
        final messages = buildGenkitMessages(
          systemInstruction: '',
          storedMessages: [message],
          storedAttachmentsByMessageId: {
            9: [
              buildAttachment(
                messageId: 9,
                kind: 'image',
                name: 'one.png',
                sourceType: 'png',
                path: '/tmp/one.png',
              ),
              buildAttachment(
                id: 2,
                messageId: 9,
                kind: 'image',
                name: 'two.jpg',
                sourceType: 'jpg',
                path: '/tmp/two.jpg',
              ),
              buildAttachment(
                id: 3,
                messageId: 9,
                kind: 'document',
                name: 'notes.txt',
                sourceType: 'text',
                path: '/tmp/notes.txt',
                extractedText: 'Important document body',
              ),
            ],
          },
        );

        final content = messages.single.content;
        expect(content, hasLength(4));
        expect(content.first.text, 'Compare these files');
        expect(content.where((part) => part.isMedia), hasLength(2));
        expect(content.last.text, contains('BEGIN ATTACHMENT: notes.txt'));
        expect(content.last.text, contains('Important document body'));
      },
    );

    test('maps an audio attachment transcript as text, not media', () {
      final message = buildMessage(
        id: 12,
        role: 'user',
        kind: 'text',
        content: 'Summarize this recording',
      );
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [message],
        storedAttachmentsByMessageId: {
          12: [
            buildAttachment(
              messageId: 12,
              kind: 'audio',
              name: 'meeting.m4a',
              sourceType: 'm4a',
              path: '/tmp/meeting.m4a',
              extractedText: 'Budget approved for the next quarter.',
            ),
          ],
        },
      );

      expect(messages, hasLength(1));
      expect(messages.single.content, hasLength(2));
      final transcriptPart = messages.single.content.last;
      expect(transcriptPart.isMedia, isFalse);
      expect(transcriptPart.text, contains('BEGIN AUDIO TRANSCRIPT'));
      expect(transcriptPart.text, contains('Budget approved'));
      expect(transcriptPart.text, contains('END AUDIO TRANSCRIPT'));
    });

    test('maps an assistant text row to a model Message', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(role: 'assistant', kind: 'text', content: 'Hi there'),
        ],
      );
      expect(messages, hasLength(1));
      expect(messages.first.role, Role.model);
      expect(messages.first.content.single.text, 'Hi there');
    });

    test('filters out thinking, tool_trace and tool rows', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(role: 'assistant', kind: 'thinking', content: 'hmm'),
          buildMessage(role: 'assistant', kind: 'tool_trace', content: 'trace'),
          buildMessage(role: 'tool', kind: 'text', content: 'tool out'),
        ],
      );
      expect(messages, isEmpty);
    });

    test('skips rows with empty content', () {
      final messages = buildGenkitMessages(
        systemInstruction: '',
        storedMessages: [
          buildMessage(role: 'user', kind: 'text', content: '   '),
          buildMessage(role: 'assistant', kind: 'text', content: ''),
        ],
      );
      expect(messages, isEmpty);
    });
  });

  group('resolveModelConfig', () {
    test('maps local model onto LlamaDartGenerationConfig', () {
      final config =
          resolveModelConfig(
                activeModel: buildModel(
                  provider: ModelProviderType.local,
                  temperature: 0.55,
                  topP: 0.88,
                  topK: 33,
                  tokenBuffer: 256,
                  randomSeed: 999,
                  isThinking: true,
                  supportsFunctionCalls: true,
                ),
              )
              as LlamaDartGenerationConfig;
      expect(config.temperature, 0.55);
      expect(config.topP, 0.88);
      expect(config.topK, 33);
      expect(config.maxTokens, 256);
      expect(config.seed, 999);
      expect(config.enableThinking, true);
      expect(config.parallelToolCalls, true);
    });

    test('maps remote model onto OpenAIChatOptions', () {
      final config =
          resolveModelConfig(
                activeModel: buildModel(
                  provider: ModelProviderType.remote,
                  temperature: 0.3,
                  topP: 0.5,
                  tokenBuffer: 1024,
                  randomSeed: 7,
                ),
              )
              as OpenAIChatOptions;
      expect(config.temperature, 0.3);
      expect(config.topP, 0.5);
      expect(config.maxTokens, 1024);
      expect(config.seed, 7);
    });
  });

  group('shouldStringifyToolResultForGemma4LiteRt', () {
    test('true only for local gemma4 .litertlm', () {
      expect(
        shouldStringifyToolResultForGemma4LiteRt(
          buildModel(
            provider: ModelProviderType.local,
            modelType: 'gemma4',
            source: '/models/gemma4.litertlm',
          ),
        ),
        isTrue,
      );
    });

    test('false for remote provider even if gemma4 .litertlm', () {
      expect(
        shouldStringifyToolResultForGemma4LiteRt(
          buildModel(
            provider: ModelProviderType.remote,
            modelType: 'gemma4',
            source: '/models/gemma4.litertlm',
          ),
        ),
        isFalse,
      );
    });

    test('false for a different model type', () {
      expect(
        shouldStringifyToolResultForGemma4LiteRt(
          buildModel(
            provider: ModelProviderType.local,
            modelType: 'llama',
            source: '/models/gemma4.litertlm',
          ),
        ),
        isFalse,
      );
    });

    test('false for a .gguf source', () {
      expect(
        shouldStringifyToolResultForGemma4LiteRt(
          buildModel(
            provider: ModelProviderType.local,
            modelType: 'gemma4',
            source: '/models/gemma4.gguf',
          ),
        ),
        isFalse,
      );
    });
  });

  group('truncate', () {
    test('returns value unchanged when within limit', () {
      expect(truncate('hello', 10), 'hello');
    });

    test('truncates and appends ellipsis when over limit', () {
      expect(truncate('abcdef', 3), 'abc...');
    });
  });

  group('sanitizeMap', () {
    test('truncates long strings', () {
      final result = sanitizeMap(
        'x' * 100,
        maxDepth: 5,
        maxStringChars: 10,
        maxMapEntries: 10,
        maxListItems: 10,
      );
      expect(result, '${'x' * 10}...');
    });

    test('passes through num and bool', () {
      expect(
        sanitizeMap(
          42,
          maxDepth: 5,
          maxStringChars: 10,
          maxMapEntries: 10,
          maxListItems: 10,
        ),
        42,
      );
      expect(
        sanitizeMap(
          true,
          maxDepth: 5,
          maxStringChars: 10,
          maxMapEntries: 10,
          maxListItems: 10,
        ),
        true,
      );
    });

    test('caps list items and adds a more-items marker', () {
      final result =
          sanitizeMap(
                List<int>.generate(10, (i) => i),
                maxDepth: 5,
                maxStringChars: 10,
                maxMapEntries: 10,
                maxListItems: 3,
              )
              as List;
      expect(result, hasLength(4));
      expect(result.sublist(0, 3), [0, 1, 2]);
      expect(result.last, '...(7 more item(s))');
    });

    test('caps map entries and records omitted-key count', () {
      final input = <String, dynamic>{for (var i = 0; i < 5; i++) 'k$i': i};
      final result =
          sanitizeMap(
                input,
                maxDepth: 5,
                maxStringChars: 10,
                maxMapEntries: 2,
                maxListItems: 10,
              )
              as Map;
      expect(result.containsKey('__truncated__'), isTrue);
      expect(result['__truncated__'], '3 more key(s) omitted');
    });

    test('stops recursing at max depth', () {
      final deep = <String, dynamic>{
        'a': {
          'b': {'c': 'deep'},
        },
      };
      final result =
          sanitizeMap(
                deep,
                maxDepth: 1,
                maxStringChars: 100,
                maxMapEntries: 10,
                maxListItems: 10,
              )
              as Map;
      // Depth 1 sanitizes the top map; nested values are returned as-is because
      // the recursive call hits maxDepth <= 0.
      expect(result['a'], deep['a']);
    });
  });

  group('compactWebSearchResult', () {
    test('keeps at most 5 entries and truncates body and summary', () {
      final result = <String, dynamic>{
        'summary': 's' * 1000,
        'data': List<Map<String, dynamic>>.generate(
          8,
          (i) => {
            'title': 'Title $i',
            'url': 'https://example.com/$i',
            'source': 'src$i',
            'published': '2026-01-0$i',
            'body': 'b' * 500,
            'extra': 'dropped',
          },
        ),
      };

      final compacted = compactWebSearchResult(result);
      final data = compacted['data'] as List;
      expect(data, hasLength(5));
      expect(compacted['count'], 5);

      final first = data.first as Map<String, dynamic>;
      expect(first['title'], 'Title 0');
      expect(first['url'], 'https://example.com/0');
      expect(first['source'], 'src0');
      expect(first['published'], '2026-01-00');
      expect(first['body'], '${'b' * 360}...');
      expect(first.containsKey('extra'), isFalse);

      expect(compacted['summary'], '${'s' * 700}...');
    });

    test('leaves non-list data untouched', () {
      final result = <String, dynamic>{'data': 'not-a-list', 'summary': 5};
      final compacted = compactWebSearchResult(result);
      expect(compacted['data'], 'not-a-list');
      expect(compacted['summary'], 5);
    });
  });

  group('compactToolResultForModel', () {
    test('wraps result as text for the gemma4-litert stringify path', () {
      final result = <String, dynamic>{'status': 'ok', 'value': 'x' * 1000};
      final compacted = compactToolResultForModel(
        toolName: 'some_tool',
        result: result,
        stringifyForGemma4LiteRt: true,
      );
      expect(compacted.keys, ['result']);
      final text = compacted['result'] as String;
      expect(text, startsWith('Tool result: some_tool'));
      expect(text, contains('status: ok'));
    });

    test('uses web-search compaction for the web search tool', () {
      final result = <String, dynamic>{
        'data': List<Map<String, dynamic>>.generate(
          8,
          (i) => {'title': 't$i', 'body': 'b' * 500},
        ),
      };
      final compacted = compactToolResultForModel(
        toolName: 'web_search',
        result: result,
        stringifyForGemma4LiteRt: false,
      );
      expect((compacted['data'] as List), hasLength(5));
      expect(compacted['count'], 5);
    });

    test('sanitizes generic tool results', () {
      final result = <String, dynamic>{'note': 'n' * 2000};
      final compacted = compactToolResultForModel(
        toolName: 'calculator',
        result: result,
        stringifyForGemma4LiteRt: false,
      );
      expect(compacted['note'], '${'n' * 1200}...');
    });
  });

  group('extractReasoning', () {
    test('concatenates reasoning across reasoning parts', () {
      final parts = <Part>[
        ReasoningPart(reasoning: 'first '),
        TextPart(text: 'visible answer'),
        ReasoningPart(reasoning: 'second'),
      ];
      expect(extractReasoning(parts), 'first second');
    });

    test('returns empty when no reasoning is present', () {
      expect(extractReasoning([TextPart(text: 'hi')]), '');
    });
  });

  group('resolveRemoteModelId', () {
    test('prefers modelId when present', () {
      expect(
        resolveRemoteModelId(buildModel(modelId: 'gpt-x', name: 'Fallback')),
        'gpt-x',
      );
    });

    test('falls back to name when modelId is blank', () {
      expect(
        resolveRemoteModelId(buildModel(modelId: '   ', name: 'Fallback')),
        'Fallback',
      );
    });

    test('throws when neither modelId nor name is available', () {
      expect(
        () => resolveRemoteModelId(buildModel(modelId: '', name: '   ')),
        throwsStateError,
      );
    });
  });

  group('normalizeApiKey', () {
    test('strips a leading bearer prefix (case-insensitive)', () {
      expect(normalizeApiKey('Bearer abc123'), 'abc123');
      expect(normalizeApiKey('bearer  xyz '), 'xyz');
    });

    test('leaves a plain key unchanged', () {
      expect(normalizeApiKey('  sk-plain  '), 'sk-plain');
    });
  });

  group('normalizeBaseUrl', () {
    test('strips trailing slashes', () {
      expect(
        normalizeBaseUrl('https://api.test.com/v1/'),
        'https://api.test.com/v1',
      );
    });

    test('strips a trailing /chat/completions suffix', () {
      expect(
        normalizeBaseUrl('https://api.test.com/v1/chat/completions'),
        'https://api.test.com/v1',
      );
    });

    test('throws on empty input', () {
      expect(() => normalizeBaseUrl(''), throwsStateError);
    });

    test('throws on a non-http(s) scheme', () {
      expect(() => normalizeBaseUrl('ftp://api.test.com'), throwsStateError);
    });
  });

  group('ToolResultCollector', () {
    test('ignores empty and whitespace-only entries', () {
      final collector = ToolResultCollector();
      collector.add('');
      collector.add('   ');
      expect(collector.hasEntries, isFalse);
      expect(collector.buildAssistantFallback(), '');
    });

    test('joins entries with blank lines for the fallback', () {
      final collector = ToolResultCollector()
        ..add('one')
        ..add('  two  ');
      expect(collector.hasEntries, isTrue);
      expect(collector.buildAssistantFallback(), 'one\n\ntwo');
    });
  });

  group('renderToolResultText', () {
    test('renders nested maps and lists as indented text', () {
      final text = renderToolResultText('lookup', {
        'name': 'Ada',
        'tags': ['a', 'b'],
        'nested': {'k': 1},
      });
      expect(text, contains('Tool result: lookup'));
      expect(text, contains('name: Ada'));
      expect(text, contains('tags:'));
      expect(text, contains('- a'));
      expect(text, contains('nested:'));
      expect(text, contains('k: 1'));
    });

    test('handles empty maps and lists inline', () {
      expect(renderToolValueText(<String, dynamic>{}), '{}');
      expect(renderToolValueText(<dynamic>[]), '[]');
    });

    test('renders null and top-level scalar values', () {
      expect(renderToolValueText(null), 'null');
      expect(renderToolValueText('plain'), 'plain');
      expect(renderToolValueText(7), '7');
    });

    test('renders a nested list inside a list with deeper indentation', () {
      final text = renderToolValueText([
        ['x', 'y'],
      ]);
      expect(text, '-\n  - x\n  - y');
    });

    test('json-encodes complex inline values', () {
      expect(renderInlineToolValue({'a': 1}), '{"a":1}');
      expect(renderInlineToolValue(null), 'null');
      expect(renderInlineToolValue('s'), 's');
    });
  });
}
