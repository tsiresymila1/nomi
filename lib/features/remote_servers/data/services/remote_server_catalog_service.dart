import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_model_spec.dart';

class RemoteServerCatalogService {
  RemoteServerCatalogService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              sendTimeout: const Duration(seconds: 3),
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  Future<RemoteServerProbeResult> probeAndFetchModels({
    required String baseUrl,
    required String token,
  }) async {
    final normalized = normalizeApiBaseUrl(baseUrl);
    final authToken = _normalizeToken(token);
    final headers = <String, String>{};
    if (authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final endpoints = <_ProbeEndpoint>{
      _ProbeEndpoint(
        url: _joinPath(normalized, '/models'),
        kind: _ProbeKind.openAiModels,
      ),
      _ProbeEndpoint(
        url: _joinPath(normalized, '/v1/models'),
        kind: _ProbeKind.openAiModels,
      ),
      _ProbeEndpoint(
        url: _joinPath(normalized, '/api/v1/models'),
        kind: _ProbeKind.openAiModels,
      ),
      _ProbeEndpoint(
        url: _joinPath(normalized, '/api/tags'),
        kind: _ProbeKind.ollamaTags,
      ),
    }.toList(growable: false);

    var lastStatusCode = null as int?;
    var unauthorized = false;

    for (final endpoint in endpoints) {
      try {
        final response = await _dio.getUri<dynamic>(
          Uri.parse(endpoint.url),
          options: Options(headers: headers),
        );
        lastStatusCode = response.statusCode;

        if (response.statusCode == 401 || response.statusCode == 403) {
          unauthorized = true;
          continue;
        }

        if (response.statusCode != 200) continue;

        final parsed = _parseResponse(endpoint.kind, response.data);
        if (parsed.isEmpty) {
          return RemoteServerProbeResult(
            success: true,
            message: 'Connected, but no models were returned.',
            effectiveApiBaseUrl: _resolveEffectiveApiBase(normalized, endpoint),
            models: const [],
            statusCode: response.statusCode,
          );
        }

        return RemoteServerProbeResult(
          success: true,
          message: 'Connected. Found ${parsed.length} model(s).',
          effectiveApiBaseUrl: _resolveEffectiveApiBase(normalized, endpoint),
          models: parsed,
          statusCode: response.statusCode,
        );
      } catch (_) {
        // Try next endpoint.
      }
    }

    if (unauthorized) {
      return RemoteServerProbeResult(
        success: false,
        message: 'Server reachable, but token is missing or invalid (401/403).',
        effectiveApiBaseUrl: normalized,
        models: const [],
        statusCode: lastStatusCode,
      );
    }

    return RemoteServerProbeResult(
      success: false,
      message: 'Could not connect to this server or read its model list.',
      effectiveApiBaseUrl: normalized,
      models: const [],
      statusCode: lastStatusCode,
    );
  }

  String normalizeApiBaseUrl(String input) {
    final trimmed = input.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw StateError('Invalid URL. It must start with http:// or https://');
    }

    var normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/chat/completions')) {
      normalized = normalized.substring(0, normalized.length - 17);
    }

    return normalized;
  }

  String _resolveEffectiveApiBase(String base, _ProbeEndpoint endpoint) {
    if (endpoint.kind == _ProbeKind.ollamaTags) {
      if (base.endsWith('/v1')) return base;
      return '$base/v1';
    }

    if (endpoint.url.endsWith('/api/v1/models')) {
      return base.endsWith('/api/v1') ? base : '$base/api/v1';
    }

    if (endpoint.url.endsWith('/v1/models')) {
      return base.endsWith('/v1') ? base : '$base/v1';
    }

    return base;
  }

  List<RemoteServerModelSpec> _parseResponse(_ProbeKind kind, dynamic rawData) {
    final data = _toMap(rawData);
    if (data == null) return const [];

    if (kind == _ProbeKind.ollamaTags) {
      final modelsRaw = data['models'];
      if (modelsRaw is! List) return const [];

      final specs = <RemoteServerModelSpec>[];
      for (final item in modelsRaw) {
        if (item is! Map) continue;
        final model = Map<String, dynamic>.from(item);
        final id = (model['model'] ?? model['name'] ?? model['id'] ?? '')
            .toString()
            .trim();
        if (id.isEmpty) continue;

        specs.add(
          RemoteServerModelSpec(
            id: id,
            displayName: id,
            contextLength: null,
            raw: model,
          ),
        );
      }
      return specs;
    }

    final listRaw = data['data'] ?? data['models'];
    if (listRaw is! List) return const [];

    final specs = <RemoteServerModelSpec>[];
    for (final item in listRaw) {
      if (item is! Map) continue;
      final model = Map<String, dynamic>.from(item);
      final id = (model['id'] ?? model['name'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final contextLength = _readContextLength(model);
      specs.add(
        RemoteServerModelSpec(
          id: id,
          displayName: id,
          contextLength: contextLength,
          raw: model,
        ),
      );
    }

    return specs;
  }

  Map<String, dynamic>? _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int? _readContextLength(Map<String, dynamic> model) {
    final candidates = <dynamic>[
      model['context_length'],
      model['max_context_length'],
      model['max_tokens'],
      model['num_ctx'],
    ];

    final metadata = model['metadata'];
    if (metadata is Map) {
      candidates.add(metadata['context_length']);
      candidates.add(metadata['max_context_length']);
      candidates.add(metadata['max_tokens']);
    }

    for (final value in candidates) {
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }

    return null;
  }

  String _normalizeToken(String token) {
    final trimmed = token.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  String _joinPath(String base, String suffix) {
    final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
    return '$normalizedBase$suffix';
  }
}

class _ProbeEndpoint {
  const _ProbeEndpoint({required this.url, required this.kind});

  final String url;
  final _ProbeKind kind;
}

enum _ProbeKind { openAiModels, ollamaTags }
