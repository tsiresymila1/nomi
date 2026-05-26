import 'smart_task_status.dart';

class SmartTaskSnapshot {
  const SmartTaskSnapshot({
    required this.id,
    required this.name,
    required this.status,
    required this.progress,
    required this.message,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.error,
  });

  final String id;
  final String name;
  final SmartTaskStatus status;
  final double progress;
  final String message;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? error;

  bool get isTerminal {
    return status == SmartTaskStatus.completed ||
        status == SmartTaskStatus.cancelled ||
        status == SmartTaskStatus.failed;
  }

  SmartTaskSnapshot copyWith({
    String? id,
    String? name,
    SmartTaskStatus? status,
    double? progress,
    String? message,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? error = _unset,
  }) {
    return SmartTaskSnapshot(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'status': status.name,
      'progress': progress,
      'message': message,
      'payload': payload,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'error': error,
    };
  }

  factory SmartTaskSnapshot.fromMap(Map<String, dynamic> map) {
    final String statusName =
        map['status'] as String? ?? SmartTaskStatus.queued.name;

    return SmartTaskSnapshot(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      status: SmartTaskStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => SmartTaskStatus.queued,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      message: map['message'] as String? ?? '',
      payload: Map<String, dynamic>.from(
        map['payload'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      error: map['error'] as String?,
    );
  }

  static const Object _unset = Object();
}
