import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/tools/web_search_service.dart';

const String getCurrentDayToolName = 'get_current_day';
const String getDeviceInfoToolName = 'get_device_info';
const String webSearchToolName = 'web_search';
const String ragSearchToolName = 'workspace_rag_search';

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<gemma.Tool> buildChatTools({
  required bool supportsFunctionCalls,
  required bool enableRagTool,
}) {
  if (!supportsFunctionCalls) return const <gemma.Tool>[];

  final tools = <gemma.Tool>[
    gemma.Tool(
      name: getCurrentDayToolName,
      description:
          'Get the current local day and date from the device clock. Use this when the user asks what day it is or asks for today date.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    ),
    gemma.Tool(
      name: getDeviceInfoToolName,
      description:
          'Get basic device and runtime information from the current device. Use this when the user asks about device details or system info.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    ),
    gemma.Tool(
      name: webSearchToolName,
      description:
          'Search the web and return top results plus extracted markdown from pages. Use this when the user asks for recent or external information.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'query': <String, dynamic>{
            'type': 'string',
            'description': 'Search query text.',
          },
          'max_results': <String, dynamic>{
            'type': 'integer',
            'description': 'Maximum number of search results to return (1-10).',
          },
          'max_content_pages': <String, dynamic>{
            'type': 'integer',
            'description':
                'Maximum number of pages to fetch content from (1-5).',
          },
        },
        'required': <String>['query'],
      },
    ),
  ];

  if (enableRagTool) {
    tools.add(
      const gemma.Tool(
        name: ragSearchToolName,
        description:
            'Search the current workspace knowledge base (RAG documents) and return relevant snippets. Use this when the user asks about facts likely present in workspace documents.',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'query': <String, dynamic>{
              'type': 'string',
              'description':
                  'Question or search query against workspace documents.',
            },
            'top_k': <String, dynamic>{
              'type': 'integer',
              'description': 'Max snippets to return (1-8).',
            },
            'threshold': <String, dynamic>{
              'type': 'number',
              'description': 'Similarity threshold between 0.0 and 1.0.',
            },
          },
          'required': <String>['query'],
        },
      ),
    );
  }

  return tools;
}

Future<Map<String, dynamic>> executeChatTool(
  gemma.FunctionCallResponse call, {
  Future<Map<String, dynamic>> Function(
    String query, {
    int topK,
    double threshold,
  })?
  ragToolHandler,
}) async {
  logger.i(call.name);
  logger.i(call.args);
  switch (call.name) {
    case getCurrentDayToolName:
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final weekday = _weekdayNames[now.weekday - 1];
      return <String, dynamic>{
        'status': 'success',
        'date': '${now.year}-$month-$day',
        'day_of_week': weekday,
        'timezone': now.timeZoneName,
        'local_time': now.toIso8601String(),
      };
    case getDeviceInfoToolName:
      final now = DateTime.now();
      return <String, dynamic>{
        'status': 'success',
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'hostname': Platform.localHostname,
        'dart_version': Platform.version,
        'cpu_cores': Platform.numberOfProcessors,
        'is_android': Platform.isAndroid,
        'is_ios': Platform.isIOS,
        'is_macos': Platform.isMacOS,
        'is_windows': Platform.isWindows,
        'is_linux': Platform.isLinux,
        'timestamp': now.toIso8601String(),
      };
    case webSearchToolName:
      final query = (call.args['query'] ?? '').toString();
      final maxResults = _toInt(call.args['max_results'], fallback: 5);
      final maxContentPages = _toInt(
        call.args['max_content_pages'],
        fallback: 2,
      );
      return await WebSearchService.search(
        query: query,
        maxResults: maxResults,
        maxContentPages: maxContentPages,
      );
    case ragSearchToolName:
      if (ragToolHandler == null) {
        return <String, dynamic>{
          'status': 'error',
          'error': 'rag_disabled',
          'message': 'Workspace RAG tool is not available in this session.',
        };
      }
      final query = (call.args['query'] ?? '').toString().trim();
      final topK = _toInt(call.args['top_k'], fallback: 4).clamp(1, 8);
      final threshold = _toDouble(
        call.args['threshold'],
        fallback: 0.15,
      ).clamp(0.0, 1.0);
      return await ragToolHandler(query, topK: topK, threshold: threshold);
    default:
      return <String, dynamic>{
        'status': 'error',
        'error': 'unknown_tool',
        'message': 'Tool "${call.name}" is not supported by this app.',
      };
  }
}

int _toInt(Object? value, {required int fallback}) {
  if (value == null) return fallback;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? fallback;
}

double _toDouble(Object? value, {required double fallback}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}
