import 'package:flutter_test/flutter_test.dart';
import 'package:smart_background_tasks/smart_background_tasks.dart';

void main() {
  test('task snapshot map roundtrip', () {
    final SmartTaskSnapshot snapshot = SmartTaskSnapshot(
      id: '1',
      name: 'Task',
      status: SmartTaskStatus.running,
      progress: 0.5,
      message: 'Running',
      payload: const <String, dynamic>{'k': 'v'},
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    final SmartTaskSnapshot decoded = SmartTaskSnapshot.fromMap(
      snapshot.toMap(),
    );

    expect(decoded.id, '1');
    expect(decoded.status, SmartTaskStatus.running);
    expect(decoded.progress, closeTo(0.5, 0.0001));
    expect(decoded.payload['k'], 'v');
  });

  test('default model list has required entries', () {
    final List<String> names = kDefaultFlutterGemmaModelSources
        .map((model) => model.name)
        .toList();

    expect(
      names,
      containsAll(<String>['Gemma 4 E2B', 'Qwen3 0.6B', 'DeepSeek R1']),
    );
  });
}
