import 'smart_task_snapshot.dart';

enum SmartTaskEventType { state, log }

class SmartTaskEvent {
  const SmartTaskEvent({
    required this.type,
    required this.tasks,
    required this.runningCount,
    required this.timestamp,
    this.message,
  });

  final SmartTaskEventType type;
  final List<SmartTaskSnapshot> tasks;
  final int runningCount;
  final DateTime timestamp;
  final String? message;

  factory SmartTaskEvent.fromMap(Map<String, dynamic> map) {
    final String typeName =
        map['type'] as String? ?? SmartTaskEventType.state.name;
    final List<dynamic> rawTasks =
        map['tasks'] as List<dynamic>? ?? const <dynamic>[];
    return SmartTaskEvent(
      type: SmartTaskEventType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => SmartTaskEventType.state,
      ),
      tasks: rawTasks
          .whereType<Map>()
          .map(
            (item) =>
                SmartTaskSnapshot.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      runningCount: (map['runningCount'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestampMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      message: map['message'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'tasks': tasks.map((task) => task.toMap()).toList(growable: false),
      'runningCount': runningCount,
      'timestampMs': timestamp.millisecondsSinceEpoch,
      'message': message,
    };
  }
}
