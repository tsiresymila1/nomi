import 'package:gena/features/remote_servers/data/models/remote_server_protocol.dart';

class RemoteServerEntry {
  const RemoteServerEntry({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.token,
    required this.autoDiscovered,
    required this.createdAt,
    required this.lastSeenAt,
    this.protocol = RemoteServerProtocol.openAiCompatible,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String token;
  final bool autoDiscovered;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final RemoteServerProtocol protocol;

  RemoteServerEntry copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? token,
    bool? autoDiscovered,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    RemoteServerProtocol? protocol,
    bool clearLastSeenAt = false,
  }) {
    return RemoteServerEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      autoDiscovered: autoDiscovered ?? this.autoDiscovered,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: clearLastSeenAt ? null : (lastSeenAt ?? this.lastSeenAt),
      protocol: protocol ?? this.protocol,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'token': token,
      'autoDiscovered': autoDiscovered,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'protocol': protocol.storageValue,
    };
  }

  factory RemoteServerEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    final lastSeenRaw = json['lastSeenAt'];

    return RemoteServerEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      baseUrl: (json['baseUrl'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      autoDiscovered: json['autoDiscovered'] == true,
      createdAt:
          DateTime.tryParse(createdRaw?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSeenAt: DateTime.tryParse(lastSeenRaw?.toString() ?? ''),
      protocol: RemoteServerProtocol.fromStorageValue(json['protocol']),
    );
  }
}
