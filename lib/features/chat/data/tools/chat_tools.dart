import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;
import 'package:gena/core/logger.dart';
import 'package:gena/features/chat/data/tools/web_search_service.dart';
import 'package:gena/features/workspace/data/models/workspace_entity.dart';
import 'package:openai_dart/openai_dart.dart' as openai;


const String getCurrentDayToolName = 'get_current_day';
const String getDeviceInfoToolName = 'get_device_info';
const String webSearchToolName = 'web_search';
const String ragSearchToolName = 'workspace_rag_search';
const String nativeOpenUrlToolName = 'native_open_url';
const String nativeOpenAppToolName = 'native_open_app';
const String nativePhoneCallToolName = 'native_phone_call';
const String nativeReadContactsToolName = 'native_read_contacts';
const String nativeSearchContactsToolName = 'native_search_contacts';
const String nativeCreateContactToolName = 'native_create_contact';
const String nativeSendSmsToolName = 'native_send_sms';
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

const String _nativeMutatingApprovalPolicy =
    'Only send/create/delete actions require explicit user approval.';
const String _nativeMutatingActionApproval =
    'This action requires explicit user approval.';

List<gemma.Tool> buildChatTools({
  required bool supportsFunctionCalls,
  required bool enableRagTool,
  required bool enableNativeOpenUrlTool,
  required bool enableNativeOpenAppTool,
  required bool enableNativePhoneCallTool,
  required bool enableNativeContactsTool,
  required bool enableNativeSmsTool,
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
          'Search the public web and return top results plus extracted markdown from pages. If workspace RAG is available, do NOT use web search first. Use workspace_rag_search first for knowledge/context questions, then use web_search only when the user needs fresh/latest external information or when RAG does not contain the answer.',
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
            'Search the current workspace knowledge base (RAG documents) and return relevant snippets. This is the preferred first step for factual questions when RAG is enabled. Use this before web_search for non-fresh information.',
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
            'Open an external URL on the device browser. $_nativeMutatingApprovalPolicy',
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
            'Open another app through a deep link URI on the device. $_nativeMutatingApprovalPolicy',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'uri': <String, dynamic>{
              'type': 'string',
              'description':
                  'URI/deep-link to launch (for example maps:, or custom app scheme).',
            },
          },
          'required': <String>['uri'],
        },
      ),
    );
  }

  if (enableNativePhoneCallTool) {
    tools.add(
      const gemma.Tool(
        name: nativePhoneCallToolName,
        description:
            'Place a direct phone call using native device APIs. $_nativeMutatingApprovalPolicy',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'phone_number': <String, dynamic>{
              'type': 'string',
              'description': 'Target phone number to call directly.',
            },
          },
          'required': <String>['phone_number'],
        },
      ),
    );
  }

  if (enableNativeContactsTool) {
    tools.addAll(const <gemma.Tool>[
      gemma.Tool(
        name: nativeReadContactsToolName,
        description:
            'Read contacts from the device address book. $_nativeMutatingApprovalPolicy',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'limit': <String, dynamic>{
              'type': 'integer',
              'description':
                  'Maximum contacts to return (default 50, max 200).',
            },
          },
          'required': <String>[],
        },
      ),
      gemma.Tool(
        name: nativeSearchContactsToolName,
        description:
            'Search contacts by name or query text in device address book. $_nativeMutatingApprovalPolicy',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'query': <String, dynamic>{
              'type': 'string',
              'description': 'Name or query to search contacts.',
            },
            'limit': <String, dynamic>{
              'type': 'integer',
              'description':
                  'Maximum contacts to return (default 20, max 100).',
            },
          },
          'required': <String>['query'],
        },
      ),
      gemma.Tool(
        name: nativeCreateContactToolName,
        description:
            'Create a new contact in the device address book. $_nativeMutatingActionApproval',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'given_name': <String, dynamic>{
              'type': 'string',
              'description': 'Contact first/given name.',
            },
            'family_name': <String, dynamic>{
              'type': 'string',
              'description': 'Contact last/family name.',
            },
            'phone_numbers': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': 'List of phone numbers to save.',
            },
            'emails': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': 'List of email addresses to save.',
            },
            'company': <String, dynamic>{
              'type': 'string',
              'description': 'Company name (optional).',
            },
            'job_title': <String, dynamic>{
              'type': 'string',
              'description': 'Job title (optional).',
            },
          },
          'required': <String>[],
        },
      ),
    ]);
  }

  if (enableNativeSmsTool) {
    tools.add(
      const gemma.Tool(
        name: nativeSendSmsToolName,
        description:
            'Send an SMS/MMS using native messaging APIs. $_nativeMutatingActionApproval',
        parameters: <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'message': <String, dynamic>{
              'type': 'string',
              'description': 'SMS body content.',
            },
            'recipients': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description':
                  'List of recipient phone numbers (one or multiple).',
            },
          },
          'required': <String>['message', 'recipients'],
        },
      ),
    );
  }

  if (enableNativeSendEmailTool) {
    tools.add(
      const gemma.Tool(
        name: nativeSendEmailToolName,
        description:
            'Compose an email in the user email app. $_nativeMutatingActionApproval',
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
            'Turn the device flashlight on or off. $_nativeMutatingApprovalPolicy',
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

List<openai.Tool> buildRemoteChatTools({
  required bool supportsFunctionCalls,
  required bool enableRagTool,
  required bool enableNativeOpenUrlTool,
  required bool enableNativeOpenAppTool,
  required bool enableNativePhoneCallTool,
  required bool enableNativeContactsTool,
  required bool enableNativeSmsTool,
  required bool enableNativeSendEmailTool,
  required bool enableNativeFlashlightTool,
}) {
  if (!supportsFunctionCalls) return const <openai.Tool>[];

  final tools = <openai.Tool>[
    openai.Tool.function(
      name: getCurrentDayToolName,
      description:
          'Get the current local day and date from the device clock. Use this when the user asks what day it is or asks for today date.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    ),
    openai.Tool.function(
      name: getDeviceInfoToolName,
      description:
          'Get basic device and runtime information from the current device. Use this when the user asks about device details or system info.',
      parameters: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    ),
    openai.Tool.function(
      name: webSearchToolName,
      description:
          'Search the public web and return top results plus extracted markdown from pages. If workspace RAG is available, do NOT use web search first. Use workspace_rag_search first for knowledge/context questions, then use web_search only when the user needs fresh/latest external information or when RAG does not contain the answer.',
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
      openai.Tool.function(
        name: ragSearchToolName,
        description:
            'Search the current workspace knowledge base (RAG documents) and return relevant snippets. This is the preferred first step for factual questions when RAG is enabled. Use this before web_search for non-fresh information.',
        parameters: const <String, dynamic>{
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
      openai.Tool.function(
        name: nativeOpenUrlToolName,
        description:
            'Open an external URL on the device browser. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
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
      openai.Tool.function(
        name: nativeOpenAppToolName,
        description:
            'Open another app through a deep link URI on the device. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'uri': <String, dynamic>{
              'type': 'string',
              'description':
                  'URI/deep-link to launch (for example maps:, or custom app scheme).',
            },
          },
          'required': <String>['uri'],
        },
      ),
    );
  }

  if (enableNativePhoneCallTool) {
    tools.add(
      openai.Tool.function(
        name: nativePhoneCallToolName,
        description:
            'Place a direct phone call using native device APIs. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'phone_number': <String, dynamic>{
              'type': 'string',
              'description': 'Target phone number to call directly.',
            },
          },
          'required': <String>['phone_number'],
        },
      ),
    );
  }

  if (enableNativeContactsTool) {
    tools.addAll(<openai.Tool>[
      openai.Tool.function(
        name: nativeReadContactsToolName,
        description:
            'Read contacts from the device address book. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'limit': <String, dynamic>{
              'type': 'integer',
              'description':
                  'Maximum contacts to return (default 50, max 200).',
            },
          },
          'required': <String>[],
        },
      ),
      openai.Tool.function(
        name: nativeSearchContactsToolName,
        description:
            'Search contacts by name or query text in device address book. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'query': <String, dynamic>{
              'type': 'string',
              'description': 'Name or query to search contacts.',
            },
            'limit': <String, dynamic>{
              'type': 'integer',
              'description':
                  'Maximum contacts to return (default 20, max 100).',
            },
          },
          'required': <String>['query'],
        },
      ),
      openai.Tool.function(
        name: nativeCreateContactToolName,
        description:
            'Create a new contact in the device address book. $_nativeMutatingActionApproval',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'given_name': <String, dynamic>{
              'type': 'string',
              'description': 'Contact first/given name.',
            },
            'family_name': <String, dynamic>{
              'type': 'string',
              'description': 'Contact last/family name.',
            },
            'phone_numbers': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': 'List of phone numbers to save.',
            },
            'emails': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description': 'List of email addresses to save.',
            },
            'company': <String, dynamic>{
              'type': 'string',
              'description': 'Company name (optional).',
            },
            'job_title': <String, dynamic>{
              'type': 'string',
              'description': 'Job title (optional).',
            },
          },
          'required': <String>[],
        },
      ),
    ]);
  }

  if (enableNativeSmsTool) {
    tools.add(
      openai.Tool.function(
        name: nativeSendSmsToolName,
        description:
            'Send an SMS/MMS using native messaging APIs. $_nativeMutatingActionApproval',
        parameters: const <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'message': <String, dynamic>{
              'type': 'string',
              'description': 'SMS body content.',
            },
            'recipients': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
              'description':
                  'List of recipient phone numbers (one or multiple).',
            },
          },
          'required': <String>['message', 'recipients'],
        },
      ),
    );
  }

  if (enableNativeSendEmailTool) {
    tools.add(
      openai.Tool.function(
        name: nativeSendEmailToolName,
        description:
            'Compose an email in the user email app. $_nativeMutatingActionApproval',
        parameters: const <String, dynamic>{
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
      openai.Tool.function(
        name: nativeFlashlightToolName,
        description:
            'Turn the device flashlight on or off. $_nativeMutatingApprovalPolicy',
        parameters: const <String, dynamic>{
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
  return executeChatToolByName(
    call.name,
    _toArgsMap(call.args),
    ragToolHandler: ragToolHandler,
    nativeToolHandler: nativeToolHandler,
  );
}

Future<Map<String, dynamic>> executeChatToolByName(
  String toolName,
  Map<String, dynamic> args, {
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
  logger.i(toolName);
  logger.i(args);
  switch (toolName) {
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
      final query = (args['query'] ?? '').toString();
      final maxResults = _toInt(args['max_results'], fallback: 5);
      final maxContentPages = _toInt(args['max_content_pages'], fallback: 2);
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
      final query = (args['query'] ?? '').toString().trim();
      final topK = _toInt(args['top_k'], fallback: 4).clamp(1, 8);
      final threshold = _toDouble(
        args['threshold'],
        fallback: 0.15,
      ).clamp(0.0, 1.0);
      return await ragToolHandler(query, topK: topK, threshold: threshold);
    case nativeOpenUrlToolName:
    case nativeOpenAppToolName:
    case nativePhoneCallToolName:
    case nativeReadContactsToolName:
    case nativeSearchContactsToolName:
    case nativeCreateContactToolName:
    case nativeSendSmsToolName:
    case nativeSendEmailToolName:
    case nativeFlashlightToolName:
      if (nativeToolHandler == null) {
        return <String, dynamic>{
          'status': 'error',
          'error': 'native_tools_disabled',
          'message': 'Native action tools are not available in this workspace.',
        };
      }
      return nativeToolHandler(toolName, args);
    default:
      return <String, dynamic>{
        'status': 'error',
        'error': 'unknown_tool',
        'message': 'Tool "$toolName" is not supported by this app.',
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

bool isNativeToolAllowed({
  required WorkspaceEntity? workspace,
  required String toolName,
}) {
  if (workspace == null) return false;
  if (!workspace.nativeToolsEnabled) return false;
  return switch (toolName) {
    nativeOpenUrlToolName => workspace.nativeOpenUrlEnabled,
    nativeOpenAppToolName => workspace.nativeOpenAppEnabled,
    nativePhoneCallToolName => workspace.nativeOpenAppEnabled,
    nativeReadContactsToolName => workspace.nativeOpenAppEnabled,
    nativeSearchContactsToolName => workspace.nativeOpenAppEnabled,
    nativeCreateContactToolName => workspace.nativeOpenAppEnabled,
    nativeSendSmsToolName => workspace.nativeOpenAppEnabled,
    nativeSendEmailToolName => workspace.nativeSendEmailEnabled,
    nativeFlashlightToolName => workspace.nativeFlashlightEnabled,
    _ => true,
  };
}

