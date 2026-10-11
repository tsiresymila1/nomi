import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/remote_servers/data/models/remote_server_protocol.dart';
import 'package:gena/features/remote_servers/data/services/remote_server_catalog_service.dart';

void main() {
  test(
    'probes an Anthropic server with its native headers and endpoint',
    () async {
      final adapter = _RecordingAdapter(
        response: ResponseBody.fromString(
          '{"data":[{"id":"claude-sonnet-test","type":"model"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      dio.httpClientAdapter = adapter;
      final service = RemoteServerCatalogService(dio: dio);

      final result = await service.probeAndFetchModels(
        baseUrl: 'https://api.anthropic.com/v1/messages',
        token: 'Bearer test-key',
        protocol: RemoteServerProtocol.anthropic,
      );

      expect(result.success, isTrue);
      expect(result.effectiveApiBaseUrl, 'https://api.anthropic.com');
      expect(result.models.single.id, 'claude-sonnet-test');
      expect(adapter.lastRequest?.uri.path, '/v1/models');
      expect(adapter.lastRequest?.headers['x-api-key'], 'test-key');
      expect(adapter.lastRequest?.headers['anthropic-version'], '2023-06-01');
      expect(adapter.lastRequest?.headers['Authorization'], isNull);
    },
  );

  test('keeps OpenAI-compatible bearer authentication', () async {
    final adapter = _RecordingAdapter(
      response: ResponseBody.fromString(
        '{"data":[{"id":"local-model"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    dio.httpClientAdapter = adapter;
    final service = RemoteServerCatalogService(dio: dio);

    final result = await service.probeAndFetchModels(
      baseUrl: 'http://192.168.1.2:1234/v1',
      token: 'secret',
    );

    expect(result.success, isTrue);
    expect(result.models.single.id, 'local-model');
    expect(adapter.lastRequest?.uri.path, '/v1/models');
    expect(adapter.lastRequest?.headers['Authorization'], 'Bearer secret');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.response});

  final ResponseBody response;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}
