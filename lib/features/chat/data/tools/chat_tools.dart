import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/tools/web_search_service.dart';

const String getCurrentDayToolName = 'get_current_day';
const String getDeviceInfoToolName = 'get_device_info';
const String webSearchToolName = 'web_search';

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

List<gemma.Tool> buildChatTools({required bool supportsFunctionCalls}) {
  if (!supportsFunctionCalls) return const <gemma.Tool>[];

  return const <gemma.Tool>[
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
}

Future<Map<String, dynamic>> executeChatTool(
  gemma.FunctionCallResponse call,
) async {
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
