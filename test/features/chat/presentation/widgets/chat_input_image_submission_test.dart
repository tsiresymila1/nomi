import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/widgets/chat_input.dart';

void main() {
  test('takes and clears an image prompt before asynchronous generation', () {
    final controller = TextEditingController(text: '  A quiet harbor  ');
    addTearDown(controller.dispose);

    final prompt = takeImageGenerationPrompt(controller);

    expect(prompt, 'A quiet harbor');
    expect(controller.text, isEmpty);
  });

  test('does not mutate an empty image prompt', () {
    final controller = TextEditingController(text: '   ');
    addTearDown(controller.dispose);

    final prompt = takeImageGenerationPrompt(controller);

    expect(prompt, isEmpty);
    expect(controller.text, '   ');
  });
}
