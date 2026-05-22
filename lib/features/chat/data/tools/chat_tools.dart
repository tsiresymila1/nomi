import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/tools/web_search_service.dart';

const String getCurrentDayToolName = 'get_current_day';
const String getDeviceInfoToolName = 'get_device_info';
const String webSearchToolName = 'web_search';
const String ragSearchToolName = 'workspace_rag_search';
const String nativeOpenUrlToolName = 'native_open_url';
const String nativeOpenAppToolName = 'native_open_app';
const String nativeSendEmailToolName = 'native_send_email';
const String nativeFlashlightToolName = 'native_flashlight';

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
  required bool enableNativeOpenUrlTool,
  required bool enableNativeOpenAppTool,
  required bool enableNativeSendEmailTool,
  required bool enableNativeFlashlightTool,
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

  if (enableNativeOpenUrlTool) {
    tools.add(
      const gemma.Tool(
        name: nativeOpenUrlToolName,
        description:
            'Open an external URL on the device browser. Requires explicit user approval before execution.',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'url': <String, dynamic>{
              'type': 'string',
              'description': 'HTTP/HTTPS URL to open.',
            },
          },
          'required': <String>['url'],
        },
      ),
    );
  }

  if (enableNativeOpenAppTool) {
    tools.add(
      const gemma.Tool(
        name: nativeOpenAppToolName,
        description:
            'Open another app through a deep link URI on the device. Requires explicit user approval before execution.',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'uri': <String, dynamic>{
              'type': 'string',
              'description':
                  'URI/deep-link to launch (for example tel:, maps:, custom app scheme).',
            },
          },
          'required': <String>['uri'],
        },
      ),
    );
  }

  if (enableNativeSendEmailTool) {
    tools.add(
      const gemma.Tool(
        name: nativeSendEmailToolName,
        description:
            'Compose an email in the user email app. Requires explicit user approval before execution.',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'to': <String, dynamic>{
              'type': 'string',
              'description': 'Recipient email address.',
            },
            'subject': <String, dynamic>{
              'type': 'string',
              'description': 'Email subject.',
            },
            'body': <String, dynamic>{
              'type': 'string',
              'description': 'Email body.',
            },
          },
          'required': <String>['to'],
        },
      ),
    );
  }

  if (enableNativeFlashlightTool) {
    tools.add(
      const gemma.Tool(
        name: nativeFlashlightToolName,
        description:
            'Turn the device flashlight on or off. Requires explicit user approval before execution.',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'mode': <String, dynamic>{
              'type': 'string',
              'description': 'Use "on" or "off".',
            },
          },
          'required': <String>['mode'],
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
  Future<Map<String, dynamic>> Function(
    String toolName,
    Map<String, dynamic> args,
  )?
  nativeToolHandler,
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
    case nativeOpenUrlToolName:
    case nativeOpenAppToolName:
    case nativeSendEmailToolName:
    case nativeFlashlightToolName:
      if (nativeToolHandler == null) {
        return <String, dynamic>{
          'status': 'error',
          'error': 'native_tools_disabled',
          'message': 'Native action tools are not available in this workspace.',
        };
      }
      final args = _toArgsMap(call.args);
      return nativeToolHandler(call.name, args);
    default:
      return <String, dynamic>{
        'status': 'error',
        'error': 'unknown_tool',
        'message': 'Tool "${call.name}" is not supported by this app.',
      };
  }
}

Map<String, dynamic> _toArgsMap(Map<Object?, Object?> rawArgs) {
  return rawArgs.map((key, value) => MapEntry(key?.toString() ?? '', value));
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
