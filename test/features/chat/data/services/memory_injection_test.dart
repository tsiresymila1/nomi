import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/chat_runtime_helpers.dart';
import 'package:gena/features/workspace/data/services/workspace_memory_actions.dart';

/// Reproduces how the chat runtime composes the memory block into the base
/// prompt before passing it to [buildSystemInstruction].
String composeSystemInstruction({
  required String basePrompt,
  required bool memoryEnabled,
  required List<String> memories,
  int charBudget = WorkspaceMemoryActions.defaultInjectionCharBudget,
}) {
  final block = memoryEnabled
      ? WorkspaceMemoryActions.composeMemoryBlock(
          contents: memories,
          charBudget: charBudget,
        )
      : '';
  final composed = block.isEmpty
      ? basePrompt
      : (basePrompt.isEmpty ? block : '$basePrompt\n\n$block');
  return buildSystemInstruction(composed);
}

void main() {
  test('includes remembered facts when memory is enabled', () {
    final instruction = composeSystemInstruction(
      basePrompt: 'You are helpful.',
      memoryEnabled: true,
      memories: ['User name is Ada', 'Prefers metric units'],
    );
    expect(instruction, contains(WorkspaceMemoryActions.memoryBlockHeader));
    expect(instruction, contains('User name is Ada'));
    expect(instruction, contains('Prefers metric units'));
    // Base prompt and date context are preserved.
    expect(instruction, contains('You are helpful.'));
    expect(instruction, contains('CURRENT LOCAL DATE CONTEXT'));
  });

  test('omits remembered facts when memory is disabled', () {
    final instruction = composeSystemInstruction(
      basePrompt: 'You are helpful.',
      memoryEnabled: false,
      memories: ['User name is Ada'],
    );
    expect(
      instruction,
      isNot(contains(WorkspaceMemoryActions.memoryBlockHeader)),
    );
    expect(instruction, isNot(contains('User name is Ada')));
  });

  test('injection is bounded by the char cap, keeping the newest', () {
    final many = List<String>.generate(
      100,
      (i) => 'Memory entry $i padded with extra characters for length',
    );
    const budget = 300;
    final instruction = composeSystemInstruction(
      basePrompt: '',
      memoryEnabled: true,
      memories: many,
      charBudget: budget,
    );
    // The injected memory block itself must respect the budget; the date
    // context is appended afterward by buildSystemInstruction.
    final headerIndex = instruction.indexOf(
      WorkspaceMemoryActions.memoryBlockHeader,
    );
    final dateIndex = instruction.indexOf('CURRENT LOCAL DATE CONTEXT');
    expect(headerIndex, greaterThanOrEqualTo(0));
    expect(dateIndex, greaterThan(headerIndex));
    final block = instruction.substring(headerIndex, dateIndex).trimRight();
    expect(block.length, lessThanOrEqualTo(budget));
    // Newest entry kept.
    expect(instruction, contains('Memory entry 0 '));
  });
}
