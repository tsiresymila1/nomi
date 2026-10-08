import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/presentation/chat_page.dart';
import 'package:gena/features/chat/presentation/cubit/chat_ui_cubits.dart';

void main() {
  testWidgets('model loading banner names the target and phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatModelSwitchStatusBanner(
            state: const ChatModelSwitchState(
              phase: ChatModelSwitchPhase.loading,
              operationId: 1,
              modelId: 7,
              modelName: 'Tiny GGUF',
              origin: ChatModelSwitchOrigin.selection,
            ),
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Loading Tiny GGUF…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('failed model banner exposes retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatModelSwitchStatusBanner(
            state: const ChatModelSwitchState(
              phase: ChatModelSwitchPhase.failed,
              operationId: 2,
              modelId: 9,
              modelName: 'Broken GGUF',
              origin: ChatModelSwitchOrigin.selection,
              errorMessage: 'Could not load Broken GGUF.',
            ),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Could not load Broken GGUF.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
