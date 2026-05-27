import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

class DiscoveredRemoteServer {
  const DiscoveredRemoteServer({
    required this.name,
    required this.baseUrl,
    required this.signature,
  });

  final String name;
  final String baseUrl;
  final String signature;
}

class RemoteServerNetworkDiscoveryService {
  RemoteServerNetworkDiscoveryService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(milliseconds: 450),
              receiveTimeout: const Duration(milliseconds: 450),
              sendTimeout: const Duration(milliseconds: 450),
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  static const List<_NetworkProbeTarget> _targets = <_NetworkProbeTarget>[
    _NetworkProbeTarget(
      name: 'Ollama',
      port: 11434,
      path: '/api/tags',
      signature: 'ollama',
    ),
    _NetworkProbeTarget(
      name: 'LM Studio',
      port: 1234,
      path: '/api/v1/models',
      signature: 'lmstudio',
    ),
    _NetworkProbeTarget(
      name: 'OpenAI-Compatible',
      port: 1234,
      path: '/v1/models',
      signature: 'openai-compatible',
    ),
  ];

  Future<List<DiscoveredRemoteServer>> scanLocalNetwork() async {
    final subnets = await _collectLocalSubnets();
    if (subnets.isEmpty) return const [];

    final addresses = <String>[];
    for (final subnet in subnets) {
      for (var i = 1; i <= 254; i++) {
        addresses.add('$subnet.$i');
      }
    }

    final results = <DiscoveredRemoteServer>[];
    const chunkSize = 35;

    for (var i = 0; i < addresses.length; i += chunkSize) {
      final chunk = addresses.skip(i).take(chunkSize);
      final futures = <Future<void>>[];

      for (final ip in chunk) {
        futures.add(_probeIp(ip, results));
      }

      await Future.wait(futures);
    }

    final byBaseUrl = <String, DiscoveredRemoteServer>{};
    for (final server in results) {
      byBaseUrl[_normalizeUrl(server.baseUrl)] = server;
    }

    return byBaseUrl.values.toList(growable: false);
  }

  Future<Set<String>> _collectLocalSubnets() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    final subnets = <String>{};
    for (final networkInterface in interfaces) {
      for (final address in networkInterface.addresses) {
        final ip = address.address.trim();
        if (!_isPrivateIpv4(ip)) continue;
        final parts = ip.split('.');
        if (parts.length != 4) continue;
        subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }

    return subnets;
  }

  Future<void> _probeIp(String ip, List<DiscoveredRemoteServer> output) async {
    for (final target in _targets) {
      final uri = Uri.parse('http://$ip:${target.port}${target.path}');
      try {
        final response = await _dio.getUri<dynamic>(uri);
        final status = response.statusCode ?? 0;

        if (status == 200) {
          output.add(
            DiscoveredRemoteServer(
              name: '${target.name} ($ip)',
              baseUrl: 'http://$ip:${target.port}',
              signature: target.signature,
            ),
          );
          return;
        }

        if (status == 401 || status == 403) {
          output.add(
            DiscoveredRemoteServer(
              name: '${target.name} ($ip)',
              baseUrl: 'http://$ip:${target.port}',
              signature: '${target.signature}-auth',
            ),
          );
          return;
        }
      } catch (_) {
        // Ignore unreachable hosts while scanning.
      }
    }
  }

  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;

    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  String _normalizeUrl(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }
}

class _NetworkProbeTarget {
  const _NetworkProbeTarget({
    required this.name,
    required this.port,
    required this.path,
    required this.signature,
  });

  final String name;
  final int port;
  final String path;
  final String signature;
}
