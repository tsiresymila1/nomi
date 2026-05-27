class RemoteServerModelSpec {
  const RemoteServerModelSpec({
    required this.id,
    required this.displayName,
    required this.raw,
    this.contextLength,
  });

  final String id;
  final String displayName;
  final int? contextLength;
  final Map<String, dynamic> raw;
}

class RemoteServerProbeResult {
  const RemoteServerProbeResult({
    required this.success,
    required this.message,
    required this.effectiveApiBaseUrl,
    required this.models,
    required this.statusCode,
  });

  final bool success;
  final String message;
  final String effectiveApiBaseUrl;
  final List<RemoteServerModelSpec> models;
  final int? statusCode;
}
